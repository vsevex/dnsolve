import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:dnsolve/src/exception.dart';
import 'package:dnsolve/src/native_bindings.dart';

part '_answer.dart';
part '_question.dart';
part '_response.dart';
part 'builder.dart';
part 'cache.dart';
part 'parsed_records.dart';
part 'statistics.dart';

/// An enumeration that represents various DNS record types.
enum RecordType {
  A,
  aaaa,
  any,
  caa,
  cds,
  cert,
  cname,
  dname,
  dnskey,
  ds,
  hinfo,
  ipseckey,
  nsec,
  nsec3Param,
  naptr,
  ptr,
  rp,
  rrsig,
  soa,
  spf,
  srv,
  sshfp,
  tlsa,
  wks,
  txt,
  ns,
  mx,
}

/// Represents a DNS server to use for resolution.
///
/// Use one of the predefined constants ([system], [google], [cloudflare]) or
/// create a custom server with [DNSServer.custom].
class DNSServer {
  /// Uses the system's default DNS resolver (/etc/resolv.conf on Unix,
  /// system DNS settings on macOS/Windows).
  static const system = DNSServer._('system', null);

  /// Google Public DNS (8.8.8.8).
  static const google = DNSServer._('google', '8.8.8.8');

  /// Cloudflare DNS (1.1.1.1).
  static const cloudflare = DNSServer._('cloudflare', '1.1.1.1');

  /// Creates a [DNSServer] targeting a custom DNS server by IP address.
  ///
  /// Example:
  /// ```dart
  /// final quad9 = DNSServer.custom('9.9.9.9');
  /// final customPort = DNSServer.custom('192.168.1.1', port: 5353);
  /// ```
  const DNSServer.custom(String address, {int port = 53})
      : _name = 'custom',
        _address = '$address:$port';

  const DNSServer._(this._name, this._address);

  final String _name;

  /// The server address string passed to the native resolver, or `null`
  /// for the system default.
  final String? _address;

  @override
  String toString() =>
      'DNSServer($_name${_address != null ? ': $_address' : ''})';
}

/// A DNS resolver that performs DNS lookups using a native resolver via FFI.
///
/// This class resolves DNS queries using the raw DNS protocol (UDP/TCP on
/// port 53) through a compiled Rust library built on
/// [hickory-dns](https://github.com/hickory-dns/hickory-dns).
///
/// Example:
/// ```dart
/// final dnsolve = DNSolve();
/// final response = await dnsolve.lookup('example.com');
/// ```
///
/// **Important**: Always call [dispose] when done to free resources:
/// ```dart
/// final dnsolve = DNSolve();
/// try {
///   // Use dnsolve...
/// } finally {
///   dnsolve.dispose();
/// }
/// ```
class DNSolve {
  /// Creates a new [DNSolve] instance with default settings.
  ///
  /// Optionally accepts a [DNSServer] to use for all queries. Defaults to
  /// [DNSServer.system] which uses the OS-configured resolver.
  DNSolve({
    DNSServer server = DNSServer.system,
    bool enableCache = false,
    int cacheMaxSize = 100,
    bool enableStatistics = false,
    int maxRetries = 0,
    Duration? retryDelay,
  })  : _server = server,
        _cache = enableCache ? _DNSCache(maxSize: cacheMaxSize) : null,
        _statistics = enableStatistics ? DNSStatistics() : null,
        _maxRetries = maxRetries,
        _retryDelay = retryDelay ?? const Duration(milliseconds: 500) {
    _disposed = false;
  }

  /// Creates a builder for configuring a [DNSolve] instance.
  ///
  /// Example:
  /// ```dart
  /// final dnsolve = DNSolve.builder()
  ///   .withServer(DNSServer.cloudflare)
  ///   .withCache(enable: true, maxSize: 200)
  ///   .withStatistics(enable: true)
  ///   .withRetries(3)
  ///   .withRetryDelay(Duration(milliseconds: 1000))
  ///   .build();
  /// ```
  static DNSolveBuilder builder() => DNSolveBuilder();

  final DNSServer _server;
  final _DNSCache? _cache;
  final DNSStatistics? _statistics;
  final int _maxRetries;
  final Duration _retryDelay;
  bool _disposed = false;

  /// Performs a DNS lookup for the given domain.
  ///
  /// Throws [InvalidDomainException] if the domain is empty or invalid.
  /// Throws [TimeoutException] if the query exceeds the specified timeout.
  /// Throws [NativeException] if the native resolver encounters an error.
  /// Throws [DNSLookupException] if the DNS query fails.
  ///
  /// Example:
  /// ```dart
  /// final response = await dnsolve.lookup(
  ///   'example.com',
  ///   type: RecordType.A,
  ///   dnsSec: true,
  ///   timeout: Duration(seconds: 10),
  /// );
  /// ```
  Future<ResolveResponse> lookup(
    /// The domain to lookup.
    String domain, {
    /// Whether to enable DNSSEC (Domain Name System Security Extensions).
    bool dnsSec = false,

    /// The DNS record type to look up (defaults to A).
    RecordType type = RecordType.A,

    /// The DNS server to use. If not specified, uses the server configured
    /// in the constructor (defaults to [DNSServer.system]).
    DNSServer? server,

    /// The timeout duration for the DNS query.
    /// Defaults to 30 seconds if not specified.
    Duration? timeout,
  }) async {
    _checkDisposed();

    if (domain.isEmpty) {
      throw InvalidDomainException(
        'Domain cannot be empty',
        domain,
      );
    }

    final effectiveServer = server ?? _server;

    // Check cache first.
    final cacheKey = _getCacheKey(domain, type, effectiveServer, dnsSec);
    if (_cache != null) {
      final cached = _cache!.get(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    final effectiveTimeout = timeout ?? const Duration(seconds: 30);
    final stopwatch = Stopwatch()..start();
    int attempts = 0;
    Exception? lastException;

    while (attempts <= _maxRetries) {
      try {
        final body = await _resolve(
          domain,
          _typeToInt(type),
          effectiveServer._address,
          dnsSec,
          effectiveTimeout,
        );

        final response =
            ResolveResponse.fromJson(json.decode(body) as Map<String, dynamic>);

        // Check DNS status code.
        if (response.status != null && response.status != 0) {
          throw DNSLookupException(
            _getDNSStatusMessage(response.status!),
            response.status,
          );
        }

        stopwatch.stop();
        _statistics?.recordQuery(stopwatch.elapsed, true);

        // Cache the response.
        _cache?.put(cacheKey, response);

        return response;
      } on TimeoutException catch (e) {
        lastException = e;
        if (attempts < _maxRetries) {
          await Future.delayed(_retryDelay * (attempts + 1));
          attempts++;
          continue;
        }
        stopwatch.stop();
        _statistics?.recordQuery(stopwatch.elapsed, false);
        rethrow;
      } on DNSolveException catch (e) {
        lastException = e;
        if (attempts < _maxRetries && e is NativeException) {
          await Future.delayed(_retryDelay * (attempts + 1));
          attempts++;
          continue;
        }
        stopwatch.stop();
        _statistics?.recordQuery(stopwatch.elapsed, false);
        rethrow;
      } catch (e) {
        lastException = NativeException(
          'Error during DNS lookup: $e',
          e,
        );
        if (attempts < _maxRetries) {
          await Future.delayed(_retryDelay * (attempts + 1));
          attempts++;
          continue;
        }
        stopwatch.stop();
        _statistics?.recordQuery(stopwatch.elapsed, false);
        throw lastException;
      }
    }

    stopwatch.stop();
    _statistics?.recordQuery(stopwatch.elapsed, false);
    throw lastException ??
        const NativeException('DNS lookup failed after retries');
  }

  /// Performs a reverse DNS lookup for the given IP address.
  ///
  /// Throws [InvalidDomainException] if the IP address is invalid.
  /// Throws [TimeoutException] if the query exceeds the specified timeout.
  /// Throws [NativeException] if the native resolver encounters an error.
  ///
  /// Example:
  /// ```dart
  /// final records = await dnsolve.reverseLookup(
  ///   '8.8.8.8',
  ///   timeout: Duration(seconds: 10),
  /// );
  /// ```
  Future<List<Record>> reverseLookup(
    /// The IP address to perform a reverse lookup for.
    String ip, {
    /// The DNS server to use. If not specified, uses the server configured
    /// in the constructor (defaults to [DNSServer.system]).
    DNSServer? server,

    /// The timeout duration for the DNS query.
    /// Defaults to 30 seconds if not specified.
    Duration? timeout,
  }) async {
    _checkDisposed();

    if (ip.isEmpty) {
      throw InvalidDomainException(
        'IP address cannot be empty',
        ip,
      );
    }

    final effectiveServer = server ?? _server;
    final effectiveTimeout = timeout ?? const Duration(seconds: 30);

    try {
      final body = await _reverseLookup(
        ip,
        effectiveServer._address,
        effectiveTimeout,
      );

      final response =
          ResolveResponse.fromJson(json.decode(body) as Map<String, dynamic>);

      // Check DNS status code.
      if (response.status != null && response.status != 0) {
        throw DNSLookupException(
          _getDNSStatusMessage(response.status!),
          response.status,
        );
      }

      return response.answer?.records ?? [];
    } on TimeoutException {
      rethrow;
    } on DNSolveException {
      rethrow;
    } catch (e) {
      throw NativeException(
        'Error during reverse DNS lookup: $e',
        e,
      );
    }
  }

  /// Runs the native resolve call in a separate isolate with a timeout.
  Future<String> _resolve(
    String domain,
    int recordType,
    String? dnsServer,
    bool dnssec,
    Duration timeout,
  ) {
    final result = Isolate.run(() {
      final resolver = NativeResolver();
      return resolver.resolve(domain, recordType, dnsServer, dnssec);
    });

    return Future.any<String>([
      result,
      Future.delayed(timeout).then<String>((_) {
        throw TimeoutException(
          'DNS query timed out',
          timeout,
        );
      }),
    ]);
  }

  /// Runs the native reverse lookup call in a separate isolate with a timeout.
  Future<String> _reverseLookup(
    String ip,
    String? dnsServer,
    Duration timeout,
  ) {
    final result = Isolate.run(() {
      final resolver = NativeResolver();
      return resolver.reverseLookup(ip, dnsServer);
    });

    return Future.any<String>([
      result,
      Future.delayed(timeout).then<String>((_) {
        throw TimeoutException(
          'Reverse DNS query timed out',
          timeout,
        );
      }),
    ]);
  }

  /// Returns a human-readable message for DNS status codes.
  String _getDNSStatusMessage(int status) {
    switch (status) {
      case 0:
        return 'No error';
      case 1:
        return 'Format error - The name server was unable to interpret the query';
      case 2:
        return 'Server failure - The name server was unable to process this query due to a problem with the name server';
      case 3:
        return 'NXDomain - Domain name does not exist';
      case 4:
        return 'Not implemented - The name server does not support the requested kind of query';
      case 5:
        return 'Refused - The name server refuses to perform the specified operation for policy reasons';
      default:
        return 'Unknown DNS error (Status: $status)';
    }
  }

  /// Checks if this instance has been disposed.
  void _checkDisposed() {
    if (_disposed) {
      throw StateError(
        'DNSolve instance has been disposed. Create a new instance.',
      );
    }
  }

  /// Performs multiple DNS lookups in parallel.
  ///
  /// Example:
  /// ```dart
  /// final responses = await dnsolve.lookupBatch(
  ///   ['example.com', 'google.com', 'github.com'],
  ///   type: RecordType.A,
  /// );
  /// ```
  Future<List<ResolveResponse>> lookupBatch(
    List<String> domains, {
    bool dnsSec = false,
    RecordType type = RecordType.A,
    DNSServer? server,
    Duration? timeout,
  }) async {
    _checkDisposed();

    if (domains.isEmpty) {
      return [];
    }

    final futures = domains.map(
      (domain) => lookup(
        domain,
        dnsSec: dnsSec,
        type: type,
        server: server,
        timeout: timeout,
      ),
    );

    return Future.wait(futures);
  }

  /// Gets query statistics if statistics are enabled.
  ///
  /// Returns `null` if statistics were not enabled in the constructor.
  DNSStatistics? get statistics => _statistics;

  /// Clears the DNS cache if caching is enabled.
  void clearCache() {
    _cache?.clear();
  }

  /// Gets the current cache size if caching is enabled.
  int? get cacheSize => _cache?.size;

  /// Generates a cache key for a query.
  String _getCacheKey(
    String domain,
    RecordType type,
    DNSServer server,
    bool dnsSec,
  ) {
    return '$domain:$type:$server:$dnsSec';
  }

  /// Disposes of resources used by this [DNSolve] instance.
  ///
  /// After calling this method, this instance should not be used anymore.
  ///
  /// It is safe to call this method multiple times.
  void dispose() {
    if (!_disposed) {
      _cache?.clear();
      _disposed = true;
    }
  }

  /// A map that associates RecordType enum values with their corresponding DNS
  /// record types (integer values).
  static const _records = {
    RecordType.A: 1,
    RecordType.aaaa: 28,
    RecordType.any: 255,
    RecordType.caa: 257,
    RecordType.cds: 59,
    RecordType.cert: 37,
    RecordType.cname: 5,
    RecordType.dname: 39,
    RecordType.dnskey: 48,
    RecordType.ds: 43,
    RecordType.hinfo: 13,
    RecordType.ipseckey: 45,
    RecordType.mx: 15,
    RecordType.naptr: 35,
    RecordType.ns: 2,
    RecordType.nsec: 47,
    RecordType.nsec3Param: 51,
    RecordType.ptr: 12,
    RecordType.rp: 17,
    RecordType.rrsig: 46,
    RecordType.soa: 6,
    RecordType.spf: 99,
    RecordType.srv: 33,
    RecordType.sshfp: 44,
    RecordType.tlsa: 52,
    RecordType.txt: 16,
    RecordType.wks: 11,
  };

  /// Converts an integer DNS record type to a [RecordType] enum value.
  static RecordType intToRecord(int type) {
    final records = _records.map((key, value) => MapEntry(value, key));

    return records[type] ?? RecordType.A;
  }

  /// Converts a [RecordType] enum value to its corresponding integer DNS record
  /// type.
  static int _typeToInt(RecordType type) => _records[type] ?? 1;
}
