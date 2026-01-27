# 2.0.0

## Breaking Changes

- **Resource Management**: `DNSolve` instances must now be disposed after use. Always call `dispose()` when done:

  ```dart
  final dnsolve = DNSolve();
  try {
    // Use dnsolve...
  } finally {
    dnsolve.dispose();
  }
  ```

- **Public API**: Private classes `_Record`, `_Answer`, and `_Question` are now public (`Record`, `Answer`, `Question`)

- **Enum Naming**: `RecordType.nsec3PARAM` renamed to `RecordType.nsec3Param` (camelCase convention)

- **Exception Handling**: `assert()` validation replaced with proper exceptions that throw in production (`InvalidDomainException`)

- **Return Types**: `reverseLookup()` now returns `List<Record>` instead of `List<_Record>`

## New Features

- **Enhanced Record Parsing**: Added structured parsing for MX, CAA, SOA, and TXT records with dedicated classes:
  - `MXRecord` - Mail Exchange records with priority and exchange
  - `CAARecord` - Certificate Authority Authorization records
  - `SOARecord` - Start of Authority records with all fields
  - `TXTRecord` - Text records with structured data

- **Batch Lookups**: Perform multiple DNS lookups in parallel with `lookupBatch()` method

- **Response Caching**: TTL-based caching system to reduce redundant queries:
  - Configurable cache size
  - Automatic TTL-based expiration
  - Cache management methods (`clearCache()`, `cacheSize`)

- **Retry Mechanism**: Automatic retry with exponential backoff:
  - Configurable max retries
  - Customizable retry delay
  - Smart retry on network errors and timeouts

- **Query Statistics**: Track DNS query performance:
  - Total queries, success/failure counts
  - Average response time
  - Success rate percentage
  - Optional statistics tracking

- **Builder Pattern**: Fluent API for configuration:

  ```dart
  final dnsolve = DNSolve.builder()
    .withCache(enable: true, maxSize: 200)
    .withStatistics(enable: true)
    .withRetries(3)
    .withRetryDelay(Duration(milliseconds: 1000))
    .build();
  ```

- **Custom HTTP Client**: Inject your own `http.Client` instance for custom timeouts, interceptors, or mocking

- **Timeout Configuration**: Configurable timeout for DNS queries (default: 30 seconds)

- **Enhanced Error Handling**: New specific exception types:
  - `DNSLookupException` - DNS query failures with status codes
  - `NetworkException` - Network connectivity errors
  - `TimeoutException` - Query timeouts
  - `InvalidDomainException` - Invalid input validation

## Bug Fixes

- **IPv6 Reverse Lookup**: Fixed incorrect IPv6 reverse lookup logic - now properly expands and reverses IPv6 addresses

- **Input Validation**: Improved IP address validation for reverse lookups

## Improvements

- Better null safety practices throughout the codebase
- Improved documentation with comprehensive examples
- Enhanced type safety with proper error handling
- Better resource management with proper cleanup

## Migration Guide

See README.md for detailed migration instructions from v1.x to v2.0.0.

## 1.0.2

## 1.0.1

## 1.0.0 - Stable Release

## Stability and Documentation Enhancements

Stability: The release has demonstrated stability since its initial launch, providing users with a reliable experience.

Documentation: Comprehensive documentation updates have been made for almost every class and property within the system. This effort aims to enhance user understanding and streamline the integration process.

## 0.6.0

- Little changes to code styling.

## 0.5.0

- Initial version.
