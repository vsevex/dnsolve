use std::net::{IpAddr, SocketAddr};
use std::str::FromStr;

use hickory_proto::rr::record_type::RecordType;
use hickory_proto::rr::RData;
use hickory_resolver::config::{NameServerConfig, Protocol, ResolverConfig, ResolverOpts};
use hickory_resolver::TokioAsyncResolver;
use serde_json::Value;

use crate::response::ResponseBuilder;

/// DNS status codes (RFC 1035 / RFC 6895).
const RCODE_NOERROR: i32 = 0;
const RCODE_FORMERR: i32 = 1;
const RCODE_SERVFAIL: i32 = 2;
const RCODE_NXDOMAIN: i32 = 3;
const RCODE_NOTIMP: i32 = 4;
const RCODE_REFUSED: i32 = 5;

/// Resolves a DNS query and returns a JSON value in DoH-compatible schema.
pub async fn resolve(
    domain: &str,
    record_type: u16,
    dns_server: Option<&str>,
    dnssec: bool,
) -> Value {
    let rtype = RecordType::from(record_type);

    let resolver = match create_resolver(dns_server, dnssec) {
        Ok(r) => r,
        Err(e) => {
            return ResponseBuilder::error(
                RCODE_SERVFAIL,
                &format!("Failed to create resolver: {}", e),
            );
        }
    };

    match resolver.lookup(domain, rtype).await {
        Ok(lookup) => {
            let mut builder = ResponseBuilder::new()
                .status(RCODE_NOERROR)
                .rd(true)
                .ra(true)
                .ad(dnssec)
                .add_question(domain, record_type);

            for record in lookup.record_iter() {
                let rtype_int = u16::from(record.record_type());
                let ttl = record.ttl();
                let name = record.name().to_string();

                if let Some(rdata) = record.data() {
                    let data = rdata_to_string(rdata);
                    builder = builder.add_answer(&name, rtype_int, ttl, &data);
                }
            }

            builder.build()
        }
        Err(e) => {
            let status = match e.kind() {
                hickory_resolver::error::ResolveErrorKind::NoRecordsFound {
                    response_code, ..
                } => match *response_code {
                    hickory_proto::op::ResponseCode::NXDomain => RCODE_NXDOMAIN,
                    hickory_proto::op::ResponseCode::Refused => RCODE_REFUSED,
                    hickory_proto::op::ResponseCode::FormErr => RCODE_FORMERR,
                    hickory_proto::op::ResponseCode::ServFail => RCODE_SERVFAIL,
                    hickory_proto::op::ResponseCode::NotImp => RCODE_NOTIMP,
                    _ => RCODE_NOERROR,
                },
                _ => RCODE_SERVFAIL,
            };

            ResponseBuilder::new()
                .status(status)
                .rd(true)
                .ra(true)
                .comment(format!("{}", e))
                .add_question(domain, record_type)
                .build()
        }
    }
}

/// Performs a reverse DNS lookup for the given IP address.
pub async fn reverse_lookup(ip: &str, dns_server: Option<&str>) -> Value {
    let addr = match IpAddr::from_str(ip) {
        Ok(addr) => addr,
        Err(e) => {
            return ResponseBuilder::error(
                RCODE_FORMERR,
                &format!("Invalid IP address '{}': {}", ip, e),
            );
        }
    };

    let resolver = match create_resolver(dns_server, false) {
        Ok(r) => r,
        Err(e) => {
            return ResponseBuilder::error(
                RCODE_SERVFAIL,
                &format!("Failed to create resolver: {}", e),
            );
        }
    };

    // Build the PTR name for the question field.
    let ptr_name = match addr {
        IpAddr::V4(v4) => {
            let octets = v4.octets();
            format!(
                "{}.{}.{}.{}.in-addr.arpa.",
                octets[3], octets[2], octets[1], octets[0]
            )
        }
        IpAddr::V6(v6) => {
            let segments = v6.octets();
            let nibbles: Vec<String> = segments
                .iter()
                .rev()
                .flat_map(|byte| {
                    vec![
                        format!("{:x}", byte & 0x0f),
                        format!("{:x}", (byte >> 4) & 0x0f),
                    ]
                })
                .collect();
            format!("{}.ip6.arpa.", nibbles.join("."))
        }
    };

    match resolver.reverse_lookup(addr).await {
        Ok(lookup) => {
            let mut builder = ResponseBuilder::new()
                .status(RCODE_NOERROR)
                .rd(true)
                .ra(true)
                .add_question(&ptr_name, u16::from(RecordType::PTR));

            for name in lookup.iter() {
                builder =
                    builder.add_answer(&ptr_name, u16::from(RecordType::PTR), 0, &name.to_string());
            }

            builder.build()
        }
        Err(e) => {
            let status = match e.kind() {
                hickory_resolver::error::ResolveErrorKind::NoRecordsFound {
                    response_code, ..
                } => match *response_code {
                    hickory_proto::op::ResponseCode::NXDomain => RCODE_NXDOMAIN,
                    _ => RCODE_SERVFAIL,
                },
                _ => RCODE_SERVFAIL,
            };

            ResponseBuilder::new()
                .status(status)
                .rd(true)
                .ra(true)
                .comment(format!("{}", e))
                .add_question(&ptr_name, u16::from(RecordType::PTR))
                .build()
        }
    }
}

/// Creates a DNS resolver, optionally targeting a specific server.
fn create_resolver(
    dns_server: Option<&str>,
    dnssec: bool,
) -> Result<TokioAsyncResolver, Box<dyn std::error::Error>> {
    let mut opts = ResolverOpts::default();
    opts.validate = dnssec;
    opts.use_hosts_file = true;

    let config = match dns_server {
        Some(server) => {
            let socket_addr = parse_server_address(server)?;
            let mut config = ResolverConfig::new();
            config.add_name_server(NameServerConfig::new(socket_addr, Protocol::Udp));
            config.add_name_server(NameServerConfig::new(socket_addr, Protocol::Tcp));
            config
        }
        None => ResolverConfig::default(),
    };

    Ok(TokioAsyncResolver::tokio(config, opts))
}

/// Parses a server address string into a SocketAddr.
/// Accepts formats: "1.1.1.1", "1.1.1.1:53", "[::1]:53"
fn parse_server_address(server: &str) -> Result<SocketAddr, Box<dyn std::error::Error>> {
    // Try parsing as SocketAddr first (handles "ip:port" format).
    if let Ok(addr) = SocketAddr::from_str(server) {
        return Ok(addr);
    }

    // Try parsing as IP address (default port 53).
    if let Ok(ip) = IpAddr::from_str(server) {
        return Ok(SocketAddr::new(ip, 53));
    }

    Err(format!("Invalid DNS server address: {}", server).into())
}

/// Converts a byte slice to a hex string.
fn to_hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{:02x}", b)).collect()
}

/// Converts RData to its string representation matching the DoH JSON format.
fn rdata_to_string(rdata: &RData) -> String {
    match rdata {
        RData::A(a) => a.0.to_string(),
        RData::AAAA(aaaa) => aaaa.0.to_string(),
        RData::CNAME(cname) => cname.0.to_string(),
        RData::MX(mx) => format!("{} {}", mx.preference(), mx.exchange()),
        RData::NS(ns) => ns.0.to_string(),
        RData::PTR(ptr) => ptr.0.to_string(),
        RData::SOA(soa) => format!(
            "{} {} {} {} {} {} {}",
            soa.mname(),
            soa.rname(),
            soa.serial(),
            soa.refresh(),
            soa.retry(),
            soa.expire(),
            soa.minimum(),
        ),
        RData::SRV(srv) => format!(
            "{} {} {} {}",
            srv.priority(),
            srv.weight(),
            srv.port(),
            srv.target(),
        ),
        RData::TXT(txt) => {
            let strings: Vec<String> = txt
                .iter()
                .map(|s| String::from_utf8_lossy(s).to_string())
                .collect();
            format!("\"{}\"", strings.join(""))
        }
        RData::CAA(caa) => {
            format!(
                "{} {} \"{}\"",
                if caa.issuer_critical() { 128 } else { 0 },
                caa.tag(),
                caa.value(),
            )
        }
        RData::TLSA(tlsa) => format!(
            "{} {} {} {}",
            u8::from(tlsa.cert_usage()),
            u8::from(tlsa.selector()),
            u8::from(tlsa.matching()),
            to_hex(tlsa.cert_data()),
        ),
        RData::SSHFP(sshfp) => format!(
            "{} {} {}",
            u8::from(sshfp.algorithm()),
            u8::from(sshfp.fingerprint_type()),
            to_hex(sshfp.fingerprint()),
        ),
        RData::HINFO(hinfo) => format!(
            "{} {}",
            String::from_utf8_lossy(hinfo.cpu()),
            String::from_utf8_lossy(hinfo.os()),
        ),
        // Fallback: use the Display trait for any other record types.
        other => format!("{}", other),
    }
}
