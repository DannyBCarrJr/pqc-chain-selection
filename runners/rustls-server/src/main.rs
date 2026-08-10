//! Minimal rustls server for the selection matrix.
//!
//! It installs a certificate resolver that prints everything the resolver is
//! given, then serves the one configured chain unconditionally. The printout is
//! the point: `ClientHello` in rustls 0.23.43 exposes `signature_schemes` and
//! seven other accessors, and there is no accessor for
//! `signature_algorithms_cert` because the extension is never parsed.
//!
//! So this resolver is not ignoring the extension out of laziness. It is
//! demonstrating that no resolver could consult it. Serving unconditionally is
//! what the default resolver effectively does on this axis too.
//!
//! Usage: rustls-selection-server <chain.pem> <key.pem> <listen-addr>

use std::io::{Read, Write};
use std::net::TcpListener;
use std::sync::Arc;

use rustls::server::{ClientHello, ResolvesServerCert};
use rustls::sign::CertifiedKey;
use rustls::{ServerConfig, ServerConnection};

#[derive(Debug)]
struct Loud(Arc<CertifiedKey>);

impl ResolvesServerCert for Loud {
    fn resolve(&self, hello: ClientHello<'_>) -> Option<Arc<CertifiedKey>> {
        // Everything the resolver can see. Compare against the ClientHello
        // struct definition: eight fields, none of them the cert-signature list.
        println!("resolver.server_name         = {:?}", hello.server_name());
        println!("resolver.signature_schemes   = {:?}", hello.signature_schemes());
        println!("resolver.named_groups        = {:?}", hello.named_groups());
        println!(
            "resolver.certificate_authorities = {:?}",
            hello.certificate_authorities().map(<[_]>::len)
        );
        println!("resolver.signature_algorithms_cert = <NO ACCESSOR EXISTS>");
        println!("serving the only configured chain, unconditionally");
        Some(self.0.clone())
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 4 {
        eprintln!("usage: {} <chain.pem> <key.pem> <addr>", args[0]);
        std::process::exit(2);
    }
    let (chain_path, key_path, addr) = (&args[1], &args[2], &args[3]);

    let provider = Arc::new(rustls::crypto::ring::default_provider());

    let certs = rustls_pemfile::certs(&mut std::io::BufReader::new(std::fs::File::open(
        chain_path,
    )?))
    .collect::<Result<Vec<_>, _>>()?;
    let key = rustls_pemfile::private_key(&mut std::io::BufReader::new(std::fs::File::open(
        key_path,
    )?))?
    .ok_or("no private key found")?;

    println!("loaded {} certificate(s) from {}", certs.len(), chain_path);

    let signing_key = provider.key_provider.load_private_key(key)?;
    let certified = Arc::new(CertifiedKey::new(certs, signing_key));

    let config = ServerConfig::builder_with_provider(provider)
        .with_safe_default_protocol_versions()?
        .with_no_client_auth()
        .with_cert_resolver(Arc::new(Loud(certified)));

    let listener = TcpListener::bind(addr)?;
    println!("listening on {}", addr);

    let (mut sock, _) = listener.accept()?;
    let mut conn = ServerConnection::new(Arc::new(config))?;

    match conn.complete_io(&mut sock) {
        Ok(_) => {
            println!("handshake: OK");
            let _ = conn.writer().write_all(b"HTTP/1.0 200 OK\r\n\r\nok\r\n");
            let _ = conn.complete_io(&mut sock);
            let mut buf = [0u8; 64];
            let _ = conn.reader().read(&mut buf);
        }
        Err(e) => println!("handshake: FAILED {e}"),
    }
    Ok(())
}
