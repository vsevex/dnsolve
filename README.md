# DNSolve

[![License: MIT][license_badge]][license_link]

DNSolve is a Dart library that provides an easy way to perform DNS lookups. It supports both forward and reverse DNS lookups, and can be used with different DNS providers.

## Overview

This project provides a convenient API wrapper for interacting with public DNS services. While it might appear to function as a traditional DNS client, it's essential to note that it operates by sending HTTP GET requests to public DNS API endpoints like Google and Cloudflare.

## Features

- ✅ Forward DNS lookups (A, AAAA, MX, SRV, TXT, and many more record types)
- ✅ Reverse DNS lookups (PTR records)
- ✅ Multiple DNS providers (Google, Cloudflare)
- ✅ DNSSEC support
- ✅ Custom HTTP client support
- ✅ Configurable timeouts
- ✅ Comprehensive error handling
- ✅ Resource management (proper cleanup)
- ✅ IPv6 support (including fixed reverse lookup)
- ✅ **Enhanced record parsing** (MX, CAA, SOA, TXT records)
- ✅ **Batch lookups** (parallel queries)
- ✅ **Response caching** (TTL-based)
- ✅ **Retry mechanism** (with exponential backoff)
- ✅ **Query statistics** (success rate, average response time)
- ✅ **Builder pattern** (fluent configuration API)

## Installation

To install DNSolve, add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  dnsolve: ^2.0.0
```

## Usage

### Basic Forward Lookup

```dart
import 'package:dnsolve/dnsolve.dart';

Future<void> main() async {
  final dnsolve = DNSolve();

  try {
    final response = await dnsolve.lookup(
      'example.com',
      type: RecordType.A,
    );

    if (response.answer?.records != null) {
      for (final record in response.answer!.records!) {
        print('${record.name}: ${record.data}');
      }
    }
  } finally {
    dnsolve.dispose(); // Always dispose when done
  }
}
```

### SRV Record Lookup

```dart
import 'dart:developer';
import 'package:dnsolve/dnsolve.dart';

Future<void> main() async {
  final dnsolve = DNSolve();

  try {
    final response = await dnsolve.lookup(
      '_xmpp._tcp.vsevex.me',
      dnsSec: true,
      type: RecordType.srv,
    );

    if (response.answer?.records != null) {
      for (final record in response.answer!.records!) {
        log(record.toBind);
      }
    }

    // Access parsed SRV records
    if (response.answer?.srvs != null) {
      for (final srv in response.answer!.srvs!) {
        print('Priority: ${srv.priority}, Port: ${srv.port}, Target: ${srv.target}');
      }
    }
  } finally {
    dnsolve.dispose();
  }
}
```

### Reverse DNS Lookup

```dart
import 'package:dnsolve/dnsolve.dart';

Future<void> main() async {
  final dnsolve = DNSolve();

  try {
    // IPv4 reverse lookup
    final records = await dnsolve.reverseLookup('8.8.8.8');
    for (final record in records) {
      print('PTR: ${record.data}');
    }

    // IPv6 reverse lookup
    final ipv6Records = await dnsolve.reverseLookup('2001:4860:4860::8888');
    for (final record in ipv6Records) {
      print('PTR: ${record.data}');
    }
  } finally {
    dnsolve.dispose();
  }
}
```

### Custom HTTP Client and Timeout

```dart
import 'package:dnsolve/dnsolve.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // Use a custom HTTP client with timeout
  final client = http.Client();
  final dnsolve = DNSolve(client: client);

  try {
    final response = await dnsolve.lookup(
      'example.com',
      timeout: Duration(seconds: 10), // Custom timeout
      provider: DNSProvider.cloudflare,
    );

    print('Status: ${response.status}');
  } finally {
    dnsolve.dispose();
  }
}
```

### Error Handling

```dart
import 'package:dnsolve/dnsolve.dart';

Future<void> main() async {
  final dnsolve = DNSolve();

  try {
    final response = await dnsolve.lookup(
      'example.com',
      timeout: Duration(seconds: 5),
    );
  } on TimeoutException catch (e) {
    print('Query timed out: ${e.message}');
  } on DNSLookupException catch (e) {
    print('DNS lookup failed: ${e.message} (Status: ${e.statusCode})');
  } on InvalidDomainException catch (e) {
    print('Invalid domain: ${e.message}');
  } on NetworkException catch (e) {
    print('Network error: ${e.message}');
  } finally {
    dnsolve.dispose();
  }
}
```

## API Reference

### DNSolve Class

#### Constructor

```dart
DNSolve({http.Client? client})
```

Creates a new DNSolve instance. Optionally accepts a custom HTTP client.

#### Methods

##### `lookup()`

Performs a forward DNS lookup.

```dart
Future<ResolveResponse> lookup(
  String domain, {
  bool dnsSec = false,
  RecordType type = RecordType.A,
  DNSProvider provider = DNSProvider.google,
  Duration? timeout,
})
```

#### `lookupBatch()`

Performs multiple DNS lookups in parallel.

```dart
Future<List<ResolveResponse>> lookupBatch(
  List<String> domains, {
  bool dnsSec = false,
  RecordType type = RecordType.A,
  DNSProvider provider = DNSProvider.google,
  Duration? timeout,
})
```

**Parameters:**

- `domain`: The domain name to lookup (required)
- `dnsSec`: Whether to enable DNSSEC (default: `false`)
- `type`: The DNS record type (default: `RecordType.A`)
- `provider`: The DNS provider to use (default: `DNSProvider.google`)
- `timeout`: Timeout duration (default: 30 seconds)

**Returns:** `Future<ResolveResponse>`

**Throws:**

- `InvalidDomainException`: If domain is empty or invalid
- `TimeoutException`: If query exceeds timeout
- `NetworkException`: If network error occurs
- `DNSLookupException`: If DNS query fails

##### `reverseLookup()`

Performs a reverse DNS lookup (PTR record).

```dart
Future<List<Record>> reverseLookup(
  String ip, {
  DNSProvider provider = DNSProvider.google,
  Duration? timeout,
})
```

**Parameters:**

- `ip`: The IP address (IPv4 or IPv6) to lookup (required)
- `provider`: The DNS provider to use (default: `DNSProvider.google`)
- `timeout`: Timeout duration (default: 30 seconds)

**Returns:** `Future<List<Record>>`

**Throws:**

- `InvalidDomainException`: If IP address is invalid
- `TimeoutException`: If query exceeds timeout
- `NetworkException`: If network error occurs
- `DNSLookupException`: If DNS query fails

##### Lookup Batch

Performs multiple DNS lookups in parallel.

```dart
Future<List<ResolveResponse>> lookupBatch(
  List<String> domains, {
  bool dnsSec = false,
  RecordType type = RecordType.A,
  DNSProvider provider = DNSProvider.google,
  Duration? timeout,
})
```

##### `statistics`

Gets query statistics if statistics are enabled.

```dart
DNSStatistics? get statistics
```

##### `clearCache()`

Clears the DNS cache if caching is enabled.

```dart
void clearCache()
```

##### `cacheSize`

Gets the current cache size if caching is enabled.

```dart
int? get cacheSize
```

##### `dispose()`

Disposes of resources used by this instance. **Always call this when done.**

```dart
void dispose()
```

##### `builder()`

Creates a builder for configuring a DNSolve instance.

```dart
static DNSolveBuilder builder()
```

### Record Types

The following DNS record types are supported:

- `A` - IPv4 address
- `aaaa` - IPv6 address
- `any` - Any record type
- `caa` - Certificate Authority Authorization
- `cds` - Child DS
- `cert` - Certificate
- `cname` - Canonical name
- `dname` - Delegation name
- `dnskey` - DNS Key
- `ds` - Delegation Signer
- `hinfo` - Host information
- `ipseckey` - IPSEC key
- `mx` - Mail exchange
- `naptr` - Name Authority Pointer
- `ns` - Name server
- `nsec` - Next Secure
- `nsec3Param` - NSEC3 parameters
- `ptr` - Pointer (for reverse lookups)
- `rp` - Responsible Person
- `rrsig` - Resource Record Signature
- `soa` - Start of Authority
- `spf` - Sender Policy Framework
- `srv` - Service locator
- `sshfp` - SSH Fingerprint
- `tlsa` - TLSA certificate
- `txt` - Text record
- `wks` - Well-known service

### DNS Providers

- `DNSProvider.google` - Google Public DNS
- `DNSProvider.cloudflare` - Cloudflare DNS

### Response Objects

#### `ResolveResponse`

Contains the DNS resolution response.

**Properties:**

- `status`: DNS status code (0 = success)
- `answer`: `Answer` object containing DNS records
- `questions`: List of `Question` objects
- `tc`, `rd`, `ra`, `ad`, `cd`: DNS flags
- `comment`: Additional comments

#### `Answer`

Contains DNS records.

**Properties:**

- `records`: List of `Record` objects
- `srvs`: List of parsed `SRVRecord` objects (if SRV type)

#### `Record`

Represents a single DNS record.

**Properties:**

- `name`: Domain name
- `rType`: Record type
- `ttl`: Time to live
- `data`: Record data

**Methods:**

- `toBind`: Returns BIND format string

#### `SRVRecord`

Represents a parsed SRV record.

**Properties:**

- `priority`: Priority value
- `weight`: Weight value
- `port`: Port number
- `target`: Target hostname
- `fqdn`: Fully qualified domain name

**Methods:**

- `sort()`: Static method to sort SRV records by priority and weight

#### `MXRecord`

Represents a parsed MX (Mail Exchange) record.

**Properties:**

- `priority`: Priority value (lower is preferred)
- `exchange`: Mail exchange hostname
- `fqdn`: Fully qualified domain name

#### `CAARecord`

Represents a parsed CAA (Certificate Authority Authorization) record.

**Properties:**

- `flags`: Flags byte
- `tag`: Tag (e.g., "issue", "issuewild")
- `value`: Value associated with the tag
- `fqdn`: Fully qualified domain name

#### `SOARecord`

Represents a parsed SOA (Start of Authority) record.

**Properties:**

- `mname`: Primary name server
- `rname`: Administrator email (with @ replaced by .)
- `serial`: Serial number
- `refresh`: Refresh interval in seconds
- `retry`: Retry interval in seconds
- `expire`: Expire time in seconds
- `minimum`: Minimum TTL in seconds
- `fqdn`: Fully qualified domain name

#### `TXTRecord`

Represents a parsed TXT record.

**Properties:**

- `text`: Text content
- `fqdn`: Fully qualified domain name

#### `DNSStatistics`

Query statistics tracking.

**Properties:**

- `totalQueries`: Total number of queries
- `successfulQueries`: Number of successful queries
- `failedQueries`: Number of failed queries
- `averageResponseTimeMs`: Average response time in milliseconds
- `successRate`: Success rate as a percentage

**Methods:**

- `reset()`: Resets all statistics

### Exception Types

- `DNSolveException`: Base exception class
- `DNSLookupException`: DNS query failed
- `NetworkException`: Network connectivity error
- `TimeoutException`: Query timeout
- `InvalidDomainException`: Invalid domain or IP address
- `ResponseException`: HTTP response error
- `SRVRecordFormatException`: SRV record parsing error

## Migration from v1.x

### Breaking Changes

1. **Resource Management**: You must now call `dispose()` when done with a `DNSolve` instance:

   ```dart
   final dnsolve = DNSolve();
   try {
     // Use dnsolve...
   } finally {
     dnsolve.dispose();
   }
   ```

2. **Public Classes**: `_Record`, `_Answer`, and `_Question` are now public (`Record`, `Answer`, `Question`)

3. **Enum Naming**: `RecordType.nsec3PARAM` is now `RecordType.nsec3Param`

4. **Exception Handling**: `assert()` validation is replaced with proper exceptions that throw in production

5. **Return Types**: `reverseLookup()` now returns `List<Record>` instead of `List<_Record>`

### New Features

- Custom HTTP client support
- Configurable timeouts
- Enhanced error handling with specific exception types
- Fixed IPv6 reverse lookup
- Better input validation
- Enhanced record parsing (MX, CAA, SOA, TXT)
- Batch lookups
- Response caching with TTL support
- Retry mechanism with exponential backoff
- Query statistics tracking
- Builder pattern for configuration

## Contributing

Contributions are welcome! If you have any improvements, bug fixes, or new features to contribute, please create a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
