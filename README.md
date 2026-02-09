# DNSolve

[![License: MIT][license_badge]][license_link]

DNSolve is a Dart library that provides an easy way to perform DNS lookups using native resolution via FFI. It supports both forward and reverse DNS lookups using the raw DNS protocol (UDP/TCP on port 53) through a compiled Rust library built on [hickory-dns](https://github.com/hickory-dns/hickory-dns).

## Overview

Unlike traditional DNS-over-HTTPS libraries, DNSolve resolves DNS queries natively using the system's DNS resolver or any custom DNS server. No HTTP requests to Google or Cloudflare -- just direct DNS protocol communication.

## Features

- Forward DNS lookups (A, AAAA, MX, SRV, TXT, and many more record types)
- Reverse DNS lookups (PTR records)
- Native DNS resolution via Rust FFI (no HTTP overhead)
- System resolver support (uses OS-configured DNS by default)
- Custom DNS servers (Google, Cloudflare, Quad9, or any IP)
- DNSSEC support
- Configurable timeouts
- Comprehensive error handling
- IPv6 support (forward and reverse lookups)
- Enhanced record parsing (MX, CAA, SOA, TXT records)
- Batch lookups (parallel queries)
- Response caching (TTL-based)
- Retry mechanism (with exponential backoff)
- Query statistics (success rate, average response time)
- Builder pattern (fluent configuration API)

## Prerequisites

DNSolve requires a compiled native library. You need [Rust](https://rustup.rs/) installed to build it.

### Building the Native Library

```bash
# From the project root
make build

# Or directly
cd native && cargo build --release
```

This produces:

- **macOS**: `native/target/release/libdnsolve_native.dylib`
- **Linux**: `native/target/release/libdnsolve_native.so`
- **Windows**: `native/target/release/dnsolve_native.dll`

Ensure the compiled library is on your library search path:

```bash
# macOS
export DYLD_LIBRARY_PATH="/path/to/dnsolve/native/target/release:$DYLD_LIBRARY_PATH"

# Linux
export LD_LIBRARY_PATH="/path/to/dnsolve/native/target/release:$LD_LIBRARY_PATH"
```

Or copy the library next to your Dart executable.

## Installation

Add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  dnsolve: ^3.0.0
```

## Usage

### Basic Forward Lookup

```dart
import 'package:dnsolve/dnsolve.dart';

Future<void> main() async {
  final dnsolve = DNSolve(); // Uses system DNS by default

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

### Custom DNS Server

```dart
import 'package:dnsolve/dnsolve.dart';

Future<void> main() async {
  // Use Cloudflare DNS
  final dnsolve = DNSolve(server: DNSServer.cloudflare);

  // Or Google DNS
  final dnsolve2 = DNSolve(server: DNSServer.google);

  // Or any custom server
  final dnsolve3 = DNSolve(server: DNSServer.custom('9.9.9.9'));

  // Or override per-query
  final dnsolve4 = DNSolve();
  try {
    final response = await dnsolve4.lookup(
      'example.com',
      server: DNSServer.custom('208.67.222.222'), // OpenDNS
    );
    print('Status: ${response.status}');
  } finally {
    dnsolve4.dispose();
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

### Builder Pattern

```dart
import 'package:dnsolve/dnsolve.dart';

Future<void> main() async {
  final dnsolve = DNSolve.builder()
      .withServer(DNSServer.cloudflare)
      .withCache(enable: true, maxSize: 200)
      .withStatistics(enable: true)
      .withRetries(3)
      .withRetryDelay(Duration(milliseconds: 500))
      .build();

  try {
    final response = await dnsolve.lookup('example.com');
    print('Status: ${response.status}');
    print('Stats: ${dnsolve.statistics}');
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
  } on NativeException catch (e) {
    print('Native resolver error: ${e.message}');
  } finally {
    dnsolve.dispose();
  }
}
```

## API Reference

### DNSolve Class

#### Constructor

```dart
DNSolve({
  DNSServer server = DNSServer.system,
  bool enableCache = false,
  int cacheMaxSize = 100,
  bool enableStatistics = false,
  int maxRetries = 0,
  Duration? retryDelay,
})
```

Creates a new DNSolve instance. Defaults to using the system DNS resolver.

#### Methods

##### `lookup()`

Performs a forward DNS lookup.

```dart
Future<ResolveResponse> lookup(
  String domain, {
  bool dnsSec = false,
  RecordType type = RecordType.A,
  DNSServer? server,
  Duration? timeout,
})
```

##### `lookupBatch()`

Performs multiple DNS lookups in parallel.

```dart
Future<List<ResolveResponse>> lookupBatch(
  List<String> domains, {
  bool dnsSec = false,
  RecordType type = RecordType.A,
  DNSServer? server,
  Duration? timeout,
})
```

**Parameters:**

- `domain`: The domain name to lookup (required)
- `dnsSec`: Whether to enable DNSSEC (default: `false`)
- `type`: The DNS record type (default: `RecordType.A`)
- `server`: DNS server override for this query (optional)
- `timeout`: Timeout duration (default: 30 seconds)

**Returns:** `Future<ResolveResponse>`

**Throws:**

- `InvalidDomainException`: If domain is empty or invalid
- `TimeoutException`: If query exceeds timeout
- `NativeException`: If native resolver encounters an error
- `DNSLookupException`: If DNS query fails

##### `reverseLookup()`

Performs a reverse DNS lookup (PTR record).

```dart
Future<List<Record>> reverseLookup(
  String ip, {
  DNSServer? server,
  Duration? timeout,
})
```

**Parameters:**

- `ip`: The IP address (IPv4 or IPv6) to lookup (required)
- `server`: DNS server override for this query (optional)
- `timeout`: Timeout duration (default: 30 seconds)

**Returns:** `Future<List<Record>>`

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

### DNS Servers

- `DNSServer.system` - System default DNS resolver (no external traffic)
- `DNSServer.google` - Google Public DNS (8.8.8.8)
- `DNSServer.cloudflare` - Cloudflare DNS (1.1.1.1)
- `DNSServer.custom('ip')` - Any custom DNS server by IP address

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
- `mxs`: List of parsed `MXRecord` objects (if MX type)
- `caas`: List of parsed `CAARecord` objects (if CAA type)
- `soas`: List of parsed `SOARecord` objects (if SOA type)
- `txts`: List of parsed `TXTRecord` objects (if TXT type)

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
- `NativeException`: Native FFI library error
- `TimeoutException`: Query timeout
- `InvalidDomainException`: Invalid domain or IP address
- `SRVRecordFormatException`: SRV record parsing error

## Migration from v2.x

### Breaking Changes

1. **Resolution method**: DNS-over-HTTPS has been replaced with native DNS resolution via Rust FFI. Queries are sent directly over UDP/TCP port 53 instead of HTTPS.

2. **DNS providers replaced with DNS servers**: `DNSProvider` enum has been replaced with `DNSServer` class:

   ```dart
   // Before (v2)
   await dnsolve.lookup('example.com', provider: DNSProvider.google);

   // After (v3)
   await dnsolve.lookup('example.com', server: DNSServer.google);

   // New: system resolver (default, no external traffic)
   await dnsolve.lookup('example.com'); // Uses DNSServer.system

   // New: custom DNS server
   await dnsolve.lookup('example.com', server: DNSServer.custom('9.9.9.9'));
   ```

3. **HTTP client removed**: The `client` constructor parameter and `withClient()` builder method have been removed. Use `server`/`withServer()` instead:

   ```dart
   // Before (v2)
   final dnsolve = DNSolve(client: http.Client());
   final dnsolve2 = DNSolve.builder().withClient(client).build();

   // After (v3)
   final dnsolve = DNSolve(server: DNSServer.cloudflare);
   final dnsolve2 = DNSolve.builder().withServer(DNSServer.cloudflare).build();
   ```

4. **Web support removed**: `dart:ffi` does not work in web browsers. The `web` platform has been removed from supported platforms.

5. **Dependencies changed**: The `http` package dependency has been replaced with `ffi`. A compiled native library is now required.

6. **Exception changes**: `ResponseException` has been removed (no more HTTP responses). `NativeException` has been added for FFI-specific errors.

### New Features

- Native DNS resolution (no HTTP overhead)
- System resolver support (no external traffic by default)
- Custom DNS server support (any IP address)
- Per-query server override

## Supported Platforms

- macOS (x86_64 and arm64)
- Linux (x86_64 and arm64)
- Windows (x86_64)
- Android (arm64, armeabi-v7a, x86_64)
- iOS (arm64)

> **Note:** Web is not supported due to `dart:ffi` limitations.

## Contributing

Contributions are welcome! If you have any improvements, bug fixes, or new features to contribute, please create a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
