mod resolver;
mod response;

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};

/// Creates a tokio runtime and blocks on the given future.
fn block_on<F: std::future::Future>(future: F) -> F::Output {
    let rt = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .expect("Failed to create tokio runtime");
    rt.block_on(future)
}

/// Helper to convert a nullable C string pointer to an Option<&str>.
unsafe fn nullable_c_str<'a>(ptr: *const c_char) -> Option<&'a str> {
    if ptr.is_null() {
        None
    } else {
        CStr::from_ptr(ptr).to_str().ok()
    }
}

/// Resolves a DNS query for the given domain and record type.
///
/// # Arguments
/// * `domain` - The domain name to resolve (C string).
/// * `record_type` - The DNS record type as an integer (e.g. 1=A, 28=AAAA, 15=MX).
/// * `dns_server` - Optional DNS server address (C string, nullable). Uses system default if null.
/// * `dnssec` - Whether to request DNSSEC validation (0=false, non-zero=true).
///
/// # Returns
/// A pointer to a JSON string in DoH-compatible format. The caller must free this
/// with `dns_free_string`.
#[no_mangle]
pub extern "C" fn dns_resolve(
    domain: *const c_char,
    record_type: c_int,
    dns_server: *const c_char,
    dnssec: c_int,
) -> *mut c_char {
    let domain_str = match unsafe { CStr::from_ptr(domain) }.to_str() {
        Ok(s) => s,
        Err(_) => {
            let error = response::ResponseBuilder::error(1, "Invalid UTF-8 in domain name");
            return to_c_string(&serde_json::to_string(&error).unwrap_or_default());
        }
    };

    let server = unsafe { nullable_c_str(dns_server) };
    let dnssec_flag = dnssec != 0;

    let result = block_on(resolver::resolve(
        domain_str,
        record_type as u16,
        server,
        dnssec_flag,
    ));

    to_c_string(&serde_json::to_string(&result).unwrap_or_default())
}

/// Performs a reverse DNS lookup for the given IP address.
///
/// # Arguments
/// * `ip` - The IP address to look up (C string, IPv4 or IPv6).
/// * `dns_server` - Optional DNS server address (C string, nullable). Uses system default if null.
///
/// # Returns
/// A pointer to a JSON string in DoH-compatible format. The caller must free this
/// with `dns_free_string`.
#[no_mangle]
pub extern "C" fn dns_reverse_lookup(ip: *const c_char, dns_server: *const c_char) -> *mut c_char {
    let ip_str = match unsafe { CStr::from_ptr(ip) }.to_str() {
        Ok(s) => s,
        Err(_) => {
            let error = response::ResponseBuilder::error(1, "Invalid UTF-8 in IP address");
            return to_c_string(&serde_json::to_string(&error).unwrap_or_default());
        }
    };

    let server = unsafe { nullable_c_str(dns_server) };

    let result = block_on(resolver::reverse_lookup(ip_str, server));

    to_c_string(&serde_json::to_string(&result).unwrap_or_default())
}

/// Frees a string that was allocated by `dns_resolve` or `dns_reverse_lookup`.
///
/// # Safety
/// The pointer must have been returned by one of the above functions and must
/// not have been freed already.
#[no_mangle]
pub extern "C" fn dns_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            drop(CString::from_raw(ptr));
        }
    }
}

/// Converts a Rust string to a C string pointer. The caller is responsible for
/// freeing this via `dns_free_string`.
fn to_c_string(s: &str) -> *mut c_char {
    CString::new(s)
        .unwrap_or_else(|_| CString::new("{}").unwrap())
        .into_raw()
}
