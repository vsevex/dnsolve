// ignore_for_file: avoid_print

import 'package:dnsolve/dnsolve.dart';
import 'package:http/http.dart' as http;

/// Comprehensive example demonstrating all DNSolve v2.0.0 features
Future<void> main() async {
  print('=== DNSolve v2.0.0 Feature Examples ===\n');

  // Example 1: Basic Forward Lookup
  await exampleBasicLookup();

  // Example 2: SRV Record Lookup with Parsed Records
  await exampleSRVLookup();

  // Example 3: Reverse DNS Lookup (IPv4 and IPv6)
  await exampleReverseLookup();

  // Example 4: Custom HTTP Client and Timeout
  await exampleCustomClient();

  // Example 5: Batch Lookups
  await exampleBatchLookups();

  // Example 6: Caching and Statistics
  await exampleCachingAndStatistics();

  // Example 7: Builder Pattern
  await exampleBuilderPattern();

  // Example 8: Enhanced Record Parsing (MX, CAA, SOA, TXT)
  await exampleEnhancedRecordParsing();

  // Example 9: Error Handling
  await exampleErrorHandling();

  print('\n=== All Examples Completed ===');
}

/// Example 1: Basic Forward Lookup
Future<void> exampleBasicLookup() async {
  print('1. Basic Forward Lookup');
  print('-' * 40);

  final dnsolve = DNSolve();

  try {
    final response = await dnsolve.lookup(
      'example.com',
    );

    print('Domain: example.com');
    print('Status: ${response.status}');
    if (response.answer?.records != null) {
      for (final record in response.answer!.records!) {
        print('  ${record.name}: ${record.data} (TTL: ${record.ttl})');
      }
    }
  } finally {
    dnsolve.dispose();
  }

  print('');
}

/// Example 2: SRV Record Lookup with Parsed Records
Future<void> exampleSRVLookup() async {
  print('2. SRV Record Lookup with Parsed Records');
  print('-' * 40);

  final dnsolve = DNSolve();

  try {
    final response = await dnsolve.lookup(
      '_xmpp._tcp.vsevex.me',
      dnsSec: true,
      type: RecordType.srv,
      timeout: const Duration(seconds: 10),
    );

    print('SRV Lookup: _xmpp._tcp.vsevex.me');
    print('Status: ${response.status}');

    // Raw records
    if (response.answer?.records != null) {
      print('\nRaw Records:');
      for (final record in response.answer!.records!) {
        print('  ${record.toBind}');
      }
    }

    // Parsed SRV records
    if (response.answer?.srvs != null) {
      print('\nParsed SRV Records:');
      for (final srv in response.answer!.srvs!) {
        print(
          '  Priority: ${srv.priority}, Weight: ${srv.weight}, '
          'Port: ${srv.port}, Target: ${srv.target}',
        );
      }

      // Sort SRV records
      final sorted = SRVRecord.sort(response.answer!.srvs!);
      print('\nSorted SRV Records (by priority and weight):');
      for (final srv in sorted) {
        print(
          '  Priority: ${srv.priority}, Weight: ${srv.weight}, '
          'Port: ${srv.port}',
        );
      }
    }
  } on DNSolveException catch (e) {
    print('DNS error: $e');
  } finally {
    dnsolve.dispose();
  }

  print('');
}

/// Example 3: Reverse DNS Lookup (IPv4 and IPv6)
Future<void> exampleReverseLookup() async {
  print('3. Reverse DNS Lookup');
  print('-' * 40);

  final dnsolve = DNSolve();

  try {
    // IPv4 reverse lookup
    print('IPv4 Reverse Lookup: 8.8.8.8');
    final ipv4Records = await dnsolve.reverseLookup('8.8.8.8');
    for (final record in ipv4Records) {
      print('  PTR: ${record.data}');
    }

    // IPv6 reverse lookup
    print('\nIPv6 Reverse Lookup: 2001:4860:4860::8888');
    try {
      final ipv6Records = await dnsolve.reverseLookup('2001:4860:4860::8888');
      for (final record in ipv6Records) {
        print('  PTR: ${record.data}');
      }
    } on DNSolveException catch (e) {
      print('  Note: IPv6 reverse lookup may not always return results: $e');
    }
  } finally {
    dnsolve.dispose();
  }

  print('');
}

/// Example 4: Custom HTTP Client and Timeout
Future<void> exampleCustomClient() async {
  print('4. Custom HTTP Client and Timeout');
  print('-' * 40);

  final client = http.Client();
  final dnsolve = DNSolve(client: client);

  try {
    final response = await dnsolve.lookup(
      'google.com',
      provider: DNSProvider.cloudflare,
      timeout: const Duration(seconds: 5),
    );

    print('Provider: Cloudflare');
    print('Timeout: 5 seconds');
    print('Status: ${response.status}');
    if (response.answer?.records != null) {
      print('Records found: ${response.answer!.records!.length}');
    }
  } finally {
    dnsolve.dispose();
  }

  print('');
}

/// Example 5: Batch Lookups
Future<void> exampleBatchLookups() async {
  print('5. Batch Lookups (Parallel Queries)');
  print('-' * 40);

  final dnsolve = DNSolve();

  try {
    final domains = ['example.com', 'google.com', 'github.com'];
    print('Querying: ${domains.join(', ')}');

    final responses = await dnsolve.lookupBatch(
      domains,
    );

    for (var i = 0; i < domains.length; i++) {
      final response = responses[i];
      print('\n${domains[i]}:');
      print('  Status: ${response.status}');
      if (response.answer?.records != null) {
        print('  Records: ${response.answer!.records!.length}');
        if (response.answer!.records!.isNotEmpty) {
          print('  First IP: ${response.answer!.records!.first.data}');
        }
      }
    }
  } finally {
    dnsolve.dispose();
  }

  print('');
}

/// Example 6: Caching and Statistics
Future<void> exampleCachingAndStatistics() async {
  print('6. Caching and Statistics');
  print('-' * 40);

  final dnsolve = DNSolve(
    enableCache: true,
    cacheMaxSize: 50,
    enableStatistics: true,
    maxRetries: 2,
  );

  try {
    const domain = 'example.com';

    // First lookup - hits the network
    print('First lookup (network):');
    final stopwatch = Stopwatch()..start();
    await dnsolve.lookup(domain);
    stopwatch.stop();
    print('  Time: ${stopwatch.elapsedMilliseconds}ms');
    print('  Cache size: ${dnsolve.cacheSize}');

    // Second lookup - served from cache
    print('\nSecond lookup (cache):');
    stopwatch.reset();
    stopwatch.start();
    await dnsolve.lookup(domain);
    stopwatch.stop();
    print('  Time: ${stopwatch.elapsedMilliseconds}ms');
    print('  Cache size: ${dnsolve.cacheSize}');

    // Check statistics
    final stats = dnsolve.statistics;
    if (stats != null) {
      print('\nStatistics:');
      print('  Total queries: ${stats.totalQueries}');
      print('  Successful: ${stats.successfulQueries}');
      print('  Failed: ${stats.failedQueries}');
      print(
        '  Average time: ${stats.averageResponseTimeMs.toStringAsFixed(2)}ms',
      );
      print(
        '  Success rate: ${stats.successRate.toStringAsFixed(2)}%',
      );
    }

    // Clear cache
    dnsolve.clearCache();
    print('\nCache cleared. New cache size: ${dnsolve.cacheSize}');
  } finally {
    dnsolve.dispose();
  }

  print('');
}

/// Example 7: Builder Pattern
Future<void> exampleBuilderPattern() async {
  print('7. Builder Pattern');
  print('-' * 40);

  final dnsolve = DNSolve.builder()
      .withCache()
      .withStatistics()
      .withRetries(3)
      .withRetryDelay(const Duration(milliseconds: 500))
      .build();

  try {
    print('Configuration:');
    print('  Cache: enabled (max size: 100)');
    print('  Statistics: enabled');
    print('  Max retries: 3');
    print('  Retry delay: 500ms');

    final response = await dnsolve.lookup('example.com');
    print('\nLookup successful:');
    print('  Status: ${response.status}');
    print('  Records: ${response.answer?.records?.length ?? 0}');
  } finally {
    dnsolve.dispose();
  }

  print('');
}

/// Example 8: Enhanced Record Parsing (MX, CAA, SOA, TXT)
Future<void> exampleEnhancedRecordParsing() async {
  print('8. Enhanced Record Parsing');
  print('-' * 40);

  final dnsolve = DNSolve();

  try {
    // MX Records
    print('MX Records:');
    try {
      final mxResponse = await dnsolve.lookup(
        'google.com',
        type: RecordType.mx,
      );
      if (mxResponse.answer?.mxs != null) {
        for (final mx in mxResponse.answer!.mxs!) {
          print(
            '  Priority: ${mx.priority}, Exchange: ${mx.exchange}',
          );
        }
      }
    } on DNSolveException catch (e) {
      print('  Error: $e');
    }

    // TXT Records
    print('\nTXT Records:');
    try {
      final txtResponse = await dnsolve.lookup(
        'google.com',
        type: RecordType.txt,
      );
      if (txtResponse.answer?.txts != null) {
        for (final txt in txtResponse.answer!.txts!) {
          print('  Text: ${txt.text}');
        }
      }
    } on DNSolveException catch (e) {
      print('  Error: $e');
    }

    // SOA Records
    print('\nSOA Records:');
    try {
      final soaResponse = await dnsolve.lookup(
        'example.com',
        type: RecordType.soa,
      );
      if (soaResponse.answer?.soas != null) {
        for (final soa in soaResponse.answer!.soas!) {
          print('  Primary NS: ${soa.mname}');
          print('  Admin: ${soa.rname}');
          print('  Serial: ${soa.serial}');
          print('  Refresh: ${soa.refresh}s');
        }
      }
    } on DNSolveException catch (e) {
      print('  Error: $e');
    }

    // CAA Records
    print('\nCAA Records:');
    try {
      final caaResponse = await dnsolve.lookup(
        'example.com',
        type: RecordType.caa,
      );
      if (caaResponse.answer?.caas != null) {
        for (final caa in caaResponse.answer!.caas!) {
          print('  Flags: ${caa.flags}, Tag: ${caa.tag}, Value: ${caa.value}');
        }
      } else {
        print('  No CAA records found');
      }
    } on DNSolveException catch (e) {
      print('  Error: $e');
    }
  } finally {
    dnsolve.dispose();
  }

  print('');
}

/// Example 9: Error Handling
Future<void> exampleErrorHandling() async {
  print('9. Error Handling');
  print('-' * 40);

  final dnsolve = DNSolve();

  try {
    // Invalid domain
    print('Testing invalid domain:');
    try {
      await dnsolve.lookup('');
    } on InvalidDomainException catch (e) {
      print('  Caught InvalidDomainException: ${e.message}');
    }

    // Non-existent domain
    print('\nTesting non-existent domain:');
    try {
      final response = await dnsolve.lookup(
        'this-domain-definitely-does-not-exist-12345.com',
        timeout: const Duration(seconds: 5),
      );
      if (response.status != null && response.status != 0) {
        print('  DNS Status: ${response.status}');
      }
    } on DNSLookupException catch (e) {
      print('  Caught DNSLookupException: ${e.message}');
      if (e.statusCode != null) {
        print('  Status Code: ${e.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('  Caught TimeoutException: ${e.message}');
    } on NetworkException catch (e) {
      print('  Caught NetworkException: ${e.message}');
    }

    // Invalid IP for reverse lookup
    print('\nTesting invalid IP:');
    try {
      await dnsolve.reverseLookup('invalid.ip.address');
    } on InvalidDomainException catch (e) {
      print('  Caught InvalidDomainException: ${e.message}');
    }
  } finally {
    dnsolve.dispose();
  }

  print('');
}
