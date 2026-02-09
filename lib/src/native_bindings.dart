import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

/// Provides Dart-friendly access to the native DNS resolver library.
///
/// This class loads the compiled Rust library (`dnsolve_native`) and wraps
/// the FFI calls into simple Dart methods that return JSON strings.
class NativeResolver {
  NativeResolver() : _lib = _loadLibrary();

  final DynamicLibrary _lib;

  /// `dns_resolve(domain, record_type, dns_server, dnssec) -> char*`
  late final Pointer<Utf8> Function(
    Pointer<Utf8> domain,
    int recordType,
    Pointer<Utf8> dnsServer,
    int dnssec,
  ) _resolve = _lib.lookupFunction<
      Pointer<Utf8> Function(
        Pointer<Utf8>,
        Int32,
        Pointer<Utf8>,
        Int32,
      ),
      Pointer<Utf8> Function(
        Pointer<Utf8>,
        int,
        Pointer<Utf8>,
        int,
      )>('dns_resolve');

  /// `dns_reverse_lookup(ip, dns_server) -> char*`
  late final Pointer<Utf8> Function(
    Pointer<Utf8> ip,
    Pointer<Utf8> dnsServer,
  ) _reverseLookup = _lib.lookupFunction<
      Pointer<Utf8> Function(
        Pointer<Utf8>,
        Pointer<Utf8>,
      ),
      Pointer<Utf8> Function(
        Pointer<Utf8>,
        Pointer<Utf8>,
      )>('dns_reverse_lookup');

  /// `dns_free_string(ptr) -> void`
  late final void Function(Pointer<Utf8>) _freeString = _lib.lookupFunction<
      Void Function(Pointer<Utf8>),
      void Function(Pointer<Utf8>)>('dns_free_string');

  /// Resolves a DNS query for [domain] with the given [recordType].
  ///
  /// Returns a JSON string in DoH-compatible format.
  ///
  /// * [dnsServer] - Optional DNS server address (e.g. "8.8.8.8" or
  ///   "1.1.1.1:53"). Pass `null` to use the system default resolver.
  /// * [dnssec] - Whether to request DNSSEC validation.
  String resolve(
    String domain,
    int recordType,
    String? dnsServer,
    bool dnssec,
  ) {
    final domainPtr = domain.toNativeUtf8();
    final serverPtr =
        dnsServer != null ? dnsServer.toNativeUtf8() : nullptr.cast<Utf8>();
    final dnssecInt = dnssec ? 1 : 0;

    final resultPtr = _resolve(domainPtr, recordType, serverPtr, dnssecInt);

    try {
      return resultPtr.toDartString();
    } finally {
      _freeString(resultPtr);
      malloc.free(domainPtr);
      if (dnsServer != null) malloc.free(serverPtr);
    }
  }

  /// Performs a reverse DNS lookup for the given [ip] address.
  ///
  /// Returns a JSON string in DoH-compatible format.
  ///
  /// * [dnsServer] - Optional DNS server address. Pass `null` to use the
  ///   system default resolver.
  String reverseLookup(String ip, String? dnsServer) {
    final ipPtr = ip.toNativeUtf8();
    final serverPtr =
        dnsServer != null ? dnsServer.toNativeUtf8() : nullptr.cast<Utf8>();

    final resultPtr = _reverseLookup(ipPtr, serverPtr);

    try {
      return resultPtr.toDartString();
    } finally {
      _freeString(resultPtr);
      malloc.free(ipPtr);
      if (dnsServer != null) malloc.free(serverPtr);
    }
  }

  /// Loads the platform-specific native library.
  static DynamicLibrary _loadLibrary() {
    if (Platform.isMacOS || Platform.isIOS) {
      return DynamicLibrary.open('libdnsolve_native.dylib');
    } else if (Platform.isLinux || Platform.isAndroid) {
      return DynamicLibrary.open('libdnsolve_native.so');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('dnsolve_native.dll');
    }
    throw UnsupportedError(
      'Unsupported platform: ${Platform.operatingSystem}',
    );
  }
}
