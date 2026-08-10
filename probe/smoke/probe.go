// The probe.
//
// Separates two questions that a normal TLS client conflates:
//
//	what did the server SEND      captured in VerifyPeerCertificate, which runs
//	                              during the handshake and sees raw DER before
//	                              anything can reject it
//	could the client USE it       the handshake outcome, reported separately
//
// That split is required, not stylistic. Go 1.26 has no ML-DSA support in
// crypto/tls or crypto/x509, so a Go client cannot complete a handshake against
// an ML-DSA leaf. Measuring which chain a server CHOSE must therefore survive
// the handshake failing, or every post-quantum cell in the matrix reads as "no
// data" when the real answer is "it sent the PQ chain and we could not use it".
//
// Raw DER is written to disk so openssl can describe certificates Go cannot
// parse. Go's own reading is reported alongside, and the two disagreeing is
// itself a result worth seeing.
//
// Build with ../tlspatch/build.sh, never `go run`: overlays are ignored there.
package main

import (
	"crypto/tls"
	"crypto/x509"
	"flag"
	"fmt"
	"os"
	"path/filepath"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:4433", "host:port")
	roots := flag.String("roots", "", "PEM file of trusted roots; empty means capture only, no verification")
	name := flag.String("servername", "localhost", "SNI name")
	dump := flag.String("dump", "", "directory to write captured DER, one file per chain position")
	flag.Parse()

	var captured [][]byte
	cfg := &tls.Config{
		ServerName: *name,
		MinVersion: tls.VersionTLS13,
		VerifyPeerCertificate: func(rawCerts [][]byte, _ [][]*x509.Certificate) error {
			captured = rawCerts
			return nil
		},
	}

	if *roots == "" {
		// Capture-only: the question is which chain arrived, not whether it
		// validates. The handshake outcome is reported on its own line, so
		// nothing here is being quietly waved through.
		cfg.InsecureSkipVerify = true
	} else {
		pem, err := os.ReadFile(*roots)
		if err != nil {
			fatal("read roots: %v", err)
		}
		pool := x509.NewCertPool()
		if !pool.AppendCertsFromPEM(pem) {
			fatal("roots %s: no certificate found", *roots)
		}
		cfg.RootCAs = pool
	}

	conn, err := tls.Dial("tcp", *addr, cfg)
	if err == nil {
		st := conn.ConnectionState()
		fmt.Printf("handshake: OK %s %s\n", tls.VersionName(st.Version), tls.CipherSuiteName(st.CipherSuite))
		conn.Close()
	} else {
		fmt.Printf("handshake: FAILED %v\n", err)
	}

	if len(captured) == 0 {
		fmt.Println("served:    NOTHING CAPTURED (no Certificate message reached the client)")
		os.Exit(0)
	}
	fmt.Printf("served:    %d certificate(s)\n", len(captured))
	for i, der := range captured {
		if *dump != "" {
			if err := os.MkdirAll(*dump, 0o755); err != nil {
				fatal("mkdir %s: %v", *dump, err)
			}
			p := filepath.Join(*dump, fmt.Sprintf("cert%d.der", i))
			if err := os.WriteFile(p, der, 0o644); err != nil {
				fatal("write %s: %v", p, err)
			}
		}
		c, perr := x509.ParseCertificate(der)
		if perr != nil {
			fmt.Printf("  [%d] go-parse: FAILED %v (%d bytes DER)\n", i, perr, len(der))
			continue
		}
		fmt.Printf("  [%d] cn=%q key=%s sig=%s (%d bytes DER)\n",
			i, c.Subject.CommonName, c.PublicKeyAlgorithm, c.SignatureAlgorithm, len(der))
	}
}

func fatal(format string, a ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", a...)
	os.Exit(1)
}
