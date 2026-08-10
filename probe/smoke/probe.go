// Phase 1 smoke test probe.
//
// Purpose: confirm two things before any patching work starts.
//  1. A stock Go client emits signature_algorithms_cert (observed server side
//     with `openssl s_server -tlsextdebug`, extension type 50).
//  2. This program can read back which certificate chain the server chose,
//     without packet capture, via ConnectionState.PeerCertificates.
//
// If both hold, the probe for Phase 1 is a patch to the contents of
// crypto/tls.supportedSignatureAlgorithmsCert, not a fork of the marshalling
// layer. See SCOPE.md Phase 1.
//
// Certificate verification stays ON. The control certificates are loaded into a
// dedicated root pool rather than switching verification off, so a passing run
// proves the served chain actually validates. Phase 4 will need to observe
// chains a client cannot use; that wants an explicit VerifyPeerCertificate
// callback recording the chain, not InsecureSkipVerify. Build it then.
package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"os"
	"path/filepath"
)

func main() {
	addr := "127.0.0.1:4433"
	if len(os.Args) > 1 {
		addr = os.Args[1]
	}

	roots := x509.NewCertPool()
	here, err := os.Getwd()
	if err != nil {
		fatal("cwd: %v", err)
	}
	for _, name := range []string{"rsa.crt", "ec.crt"} {
		pem, err := os.ReadFile(filepath.Join(here, "certs", name))
		if err != nil {
			fatal("read %s: %v (run gen-classical-pair.sh first)", name, err)
		}
		if !roots.AppendCertsFromPEM(pem) {
			fatal("parse %s: no certificate found", name)
		}
	}

	conn, err := tls.Dial("tcp", addr, &tls.Config{
		RootCAs:    roots,
		ServerName: "localhost",
		MinVersion: tls.VersionTLS13,
	})
	if err != nil {
		fatal("dial %s: %v", addr, err)
	}
	defer conn.Close()

	st := conn.ConnectionState()
	fmt.Printf("version:  %s\n", tls.VersionName(st.Version))
	fmt.Printf("cipher:   %s\n", tls.CipherSuiteName(st.CipherSuite))
	if len(st.PeerCertificates) == 0 {
		fmt.Println("chain:    NONE (server sent no certificate)")
		return
	}
	for i, c := range st.PeerCertificates {
		fmt.Printf("chain[%d]: cn=%q pubkey=%s sigalg=%s\n",
			i, c.Subject.CommonName, c.PublicKeyAlgorithm, c.SignatureAlgorithm)
	}
}

func fatal(format string, a ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", a...)
	os.Exit(1)
}
