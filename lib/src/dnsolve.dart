import 'dart:async';
import 'dart:convert';

import 'package:dnsolve/src/exception.dart';

import 'package:http/http.dart' as http;

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

/// An enumeration that represents different DNS service providers.
enum DNSProvider { google, cloudflare }

/// A DNS resolver that performs DNS lookups using DNS-over-HTTPS (DoH) providers.
///
/// This class provides methods to perform forward and reverse DNS lookups
/// using public DNS providers like Google and Cloudflare.
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
  /// Optionally accepts a custom [http.Client] instance. If not provided,
  /// a new client will be created. The client will be closed when [dispose]
  /// is called.
  DNSolve({
    http.Client? client,
    bool enableCache = false,
    int cacheMaxSize = 100,
    bool enableStatistics = false,
    int maxRetries = 0,
    Duration? retryDelay,
  })  : _client = client ?? http.Client(),
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
  ///   .withCache(enable: true, maxSize: 200)
  ///   .withStatistics(enable: true)
  ///   .withRetries(3)
  ///   .withRetryDelay(Duration(milliseconds: 1000))
  ///   .build();
  /// ```
  static DNSolveBuilder builder() => DNSolveBuilder();

  final http.Client _client;
  final _DNSCache? _cache;
  final DNSStatistics? _statistics;
  final int _maxRetries;
  final Duration _retryDelay;
  bool _disposed = false;

  /// A map that associates [DNSProvider] enum values with their respective DNS
  /// provider URLs.
  static const _dnsProviders = <DNSProvider, String>{
    DNSProvider.google: 'https://dns.google.com/resolve',
    DNSProvider.cloudflare: 'https://cloudflare-dns.com/dns-query',
  };

  /// Performs a DNS lookup for the given domain.
  ///
  /// Throws [InvalidDomainException] if the domain is empty or invalid.
  /// Throws [TimeoutException] if the query exceeds the specified timeout.
  /// Throws [NetworkException] if a network error occurs.
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

    /// The DNS provider to use (defaults to Google).
    DNSProvider provider = DNSProvider.google,

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

    // Check cache first
    final cacheKey = _getCacheKey(domain, type, provider, dnsSec);
    if (_cache != null) {
      final cached = _cache!.get(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    // Use DoH (DNS-over-HTTPS)
    final queryParams = <String, String>{};
    queryParams
      ..putIfAbsent('name', () => domain)
      ..putIfAbsent('type', () => _typeToInt(type).toString())
      ..putIfAbsent('dnssec', () => dnsSec.toString());

    final headers = <String, String>{'Accept': 'application/dns-json'};
    final url = _dnsProviders[provider] ?? 'https://dns.google.com/resolve';

    final stopwatch = Stopwatch()..start();
    int attempts = 0;
    Exception? lastException;

    while (attempts <= _maxRetries) {
      try {
        final body = await _get(
          url,
          queryParameters: queryParams,
          headers: headers,
          timeout: timeout ?? const Duration(seconds: 30),
        );

        final response =
            ResolveResponse.fromJson(json.decode(body) as Map<String, dynamic>);

        // Check DNS status code
        if (response.status != null && response.status != 0) {
          throw DNSLookupException(
            _getDNSStatusMessage(response.status!),
            response.status,
          );
        }

        stopwatch.stop();
        _statistics?.recordQuery(stopwatch.elapsed, true);

        // Cache the response
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
        if (attempts < _maxRetries && e is NetworkException) {
          await Future.delayed(_retryDelay * (attempts + 1));
          attempts++;
          continue;
        }
        stopwatch.stop();
        _statistics?.recordQuery(stopwatch.elapsed, false);
        rethrow;
      } catch (e) {
        lastException = NetworkException(
          'Network error during DNS lookup: $e',
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
        const NetworkException('DNS lookup failed after retries');
  }

  /// Performs a reverse DNS lookup for the given IP address.
  ///
  /// Throws [InvalidDomainException] if the IP address is invalid.
  /// Throws [TimeoutException] if the query exceeds the specified timeout.
  /// Throws [NetworkException] if a network error occurs.
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
    /// The DNS provider to use (defaults to Google).
    DNSProvider provider = DNSProvider.google,

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

    final queryParams = <String, String>{};
    String? reverse() {
      // IPv4 reverse lookup
      if (ip.contains('.')) {
        final parts = ip.split('.');
        if (parts.length == 4) {
          // Validate IPv4 format
          try {
            for (final part in parts) {
              final num = int.parse(part);
              if (num < 0 || num > 255) {
                return null;
              }
            }
            return '${parts.reversed.join('.')}.in-addr.arpa';
          } catch (e) {
            return null;
          }
        }
        return null;
      }
      // IPv6 reverse lookup
      else if (ip.contains(':')) {
        try {
          // Expand IPv6 address to full format
          final expanded = _expandIPv6(ip);
          if (expanded == null) {
            return null;
          }
          // Remove colons and reverse each hex digit
          final hexDigits = expanded.replaceAll(':', '').split('');
          return '${hexDigits.reversed.join('.')}.ip6.arpa';
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    final reversed = reverse();
    if (reversed == null) {
      throw InvalidDomainException(
        'Invalid IP address format: $ip',
        ip,
      );
    }

    queryParams
      ..putIfAbsent('name', () => reversed)
      ..putIfAbsent('type', () => _records[RecordType.ptr]!.toString());

    final headers = <String, String>{'Accept': 'application/dns-json'};
    final url = _dnsProviders[provider] ?? 'https://dns.google.com/resolve';

    try {
      final body = await _get(
        url,
        queryParameters: queryParams,
        headers: headers,
        timeout: timeout ?? const Duration(seconds: 30),
      );

      final response =
          ResolveResponse.fromJson(json.decode(body) as Map<String, dynamic>);

      // Check DNS status code
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
      throw NetworkException(
        'Network error during reverse DNS lookup: $e',
        e,
      );
    }
  }

  /// Sends an HTTP GET request to the specified URL with optional query
  /// parameters and headers.
  Future<String> _get(
    String url, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    late Uri uri;
    {
      if (queryParameters == null || queryParameters.isEmpty) {
        uri = Uri.parse(url);
      } else {
        uri = Uri.parse(url).replace(queryParameters: queryParameters);
      }
    }

    final response = await _client.get(uri, headers: headers).timeout(
      timeout ?? const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException(
          'HTTP request timed out',
          timeout ?? const Duration(seconds: 30),
        );
      },
    );

    return _handleResponse(response);
  }

  /// Expands an IPv6 address to its full format.
  ///
  /// Example: "2001:db8::1" -> "2001:0db8:0000:0000:0000:0000:0000:0001"
  String? _expandIPv6(String ip) {
    try {
      // Handle double colon expansion
      if (ip.contains('::')) {
        final parts = ip.split('::');
        if (parts.length != 2) {
          return null;
        }

        final leftParts = parts[0].isEmpty ? <String>[] : parts[0].split(':');
        final rightParts = parts[1].isEmpty ? <String>[] : parts[1].split(':');

        final totalParts = leftParts.length + rightParts.length;
        if (totalParts > 8) {
          return null;
        }

        final missingParts = 8 - totalParts;
        final expanded = <String>[
          ...leftParts,
          ...List.filled(missingParts, '0'),
          ...rightParts,
        ];

        return expanded.map((p) => p.padLeft(4, '0')).join(':');
      } else {
        // No double colon, just pad each part
        final parts = ip.split(':');
        if (parts.length != 8) {
          return null;
        }
        return parts.map((p) => p.padLeft(4, '0')).join(':');
      }
    } catch (e) {
      return null;
    }
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
    DNSProvider provider = DNSProvider.google,
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
        provider: provider,
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
    DNSProvider provider,
    bool dnsSec,
  ) {
    return '$domain:$type:$provider:$dnsSec';
  }

  /// Disposes of resources used by this [DNSolve] instance.
  ///
  /// This method closes the underlying HTTP client. After calling this method,
  /// this instance should not be used anymore.
  ///
  /// It is safe to call this method multiple times.
  void dispose() {
    if (!_disposed) {
      _client.close();
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
