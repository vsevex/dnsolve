import 'dart:convert';

import 'package:dnsolve/src/exception.dart';

import 'package:http/http.dart' as http;

part '_answer.dart';
part '_question.dart';
part '_response.dart';

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
  nsec3PARAM,
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

class DNSolve {
  DNSolve() {
    client = http.Client();
  }

  late final http.Client client;

  /// A map that associates [DNSProvider] enum values with their respective DNS
  /// provider URLs.
  static const _dnsProviders = <DNSProvider, String>{
    DNSProvider.google: 'https://dns.google.com/resolve',
    DNSProvider.cloudflare: 'https://cloudflare-dns.com/dns-query',
  };

  /// Performs a DNS lookup for the given domain.
  Future<ResolveResponse> lookup(
    /// The domain to lookup.
    String domain, {
    /// Whether to enable DNSSEC (Domain Name System Security Extensions).
    bool dnsSec = false,

    /// The DNS record type to look up (defaults to A).
    RecordType type = RecordType.A,

    /// The DNS provider to use (defaults to Google).
    DNSProvider provider = DNSProvider.google,
  }) async {
    assert(domain.isNotEmpty, 'domain should not be empty');

    final queryParams = <String, String>{};
    queryParams
      ..putIfAbsent('name', () => domain)
      ..putIfAbsent('type', () => _typeToInt(type).toString())
      ..putIfAbsent('dnssec', () => dnsSec.toString());

    final headers = <String, String>{'Accept': 'application/dns-json'};
    final url = _dnsProviders[provider] ?? 'https://dns.google.com/resolve';

    final body =
        await _get(url, queryParameters: queryParams, headers: headers);

    return ResolveResponse.fromJson(json.decode(body) as Map<String, dynamic>);
  }

  /// Performs a reverse DNS lookup for the given IP address.
  Future<List<_Record>> reverseLookup(
    /// The IP address to perform a reverse lookup for.
    String ip, {
    /// THE DNS provider to use (defaults to Google).
    DNSProvider provider = DNSProvider.google,
  }) async {
    final queryParams = <String, String>{};
    String? reverse() {
      if (ip.contains('.')) {
        return '${ip.split('.').reversed.join('.')}.in-addr.arpa';
      } else if (ip.contains(':')) {
        return '${ip.split(':').join().split('').reversed.join('.')}.ip6.arpa';
      } else {
        return null;
      }
    }

    final reversed = reverse();
    if (reversed == null) {
      return [];
    }

    queryParams
      ..putIfAbsent('name', () => reversed)
      ..putIfAbsent('type', () => _records[RecordType.ptr]!.toString());

    final headers = <String, String>{'Accept': 'application/dns-json'};
    final url = _dnsProviders[provider] ?? 'https://dns.google.com/resolve';

    final body =
        await _get(url, queryParameters: queryParams, headers: headers);
    final response =
        ResolveResponse.fromJson(json.decode(body) as Map<String, dynamic>);
    return response.answer!.records ?? [];
  }

  /// Sends an HTTP GET request to the specified URL with optional query
  /// parameters and headers.
  Future<String> _get(
    String url, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    late Uri uri;
    {
      if (queryParameters == null || queryParameters.isEmpty) {
        uri = Uri.parse(url);
      } else {
        uri = Uri.parse(url).replace(queryParameters: queryParameters);
      }
    }

    final response = await client.get(uri, headers: headers);
    return _handleResponse(response);
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
    RecordType.nsec3PARAM: 51,
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
