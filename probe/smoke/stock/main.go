// A dial with nothing configured, on purpose.
//
// The smoke probe (../probe.go) pins MinVersion to TLS 1.3, and that pin
// changes the ClientHello: at min 1.3 Go filters PKCS#1 v1.5 and SHA-1 out of
// signature_algorithms, at the default minimum (TLS 1.2) it filters SHA-1
// only. The published 7-versus-12 capture is therefore the min-1.3 case. This
// client exists to capture the other case: what a Go client with a default
// Config puts on the wire.
//
// ServerName and InsecureSkipVerify are the only fields set. Neither touches
// the hello's signature extensions: SNI fills extension 0, and verification
// happens after the hello is long gone. Capture-only, same idiom as the probe.
package main

import (
	"crypto/tls"
	"flag"
	"fmt"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:4433", "host:port")
	name := flag.String("servername", "localhost", "SNI name")
	flag.Parse()

	conn, err := tls.Dial("tcp", *addr, &tls.Config{
		ServerName:         *name,
		InsecureSkipVerify: true,
	})
	if err == nil {
		st := conn.ConnectionState()
		fmt.Printf("handshake: OK %s %s\n", tls.VersionName(st.Version), tls.CipherSuiteName(st.CipherSuite))
		conn.Close()
		return
	}
	fmt.Printf("handshake: FAILED %v\n", err)
}
