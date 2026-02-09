/// An abstract class representing an exception related to DNS solving.
///
/// This serves as a base class for exceptions that may occur during DNS
/// resolution or parsing operations.
abstract class DNSolveException implements Exception {
  const DNSolveException();
}

/// An exception indicating that an error occurred while parsing or processing a
/// Service (SRV) record.
///
/// This is a specific type of [DNSolveException].
class SRVRecordFormatException extends DNSolveException {
  const SRVRecordFormatException(this.message);

  final String message;
}

/// An exception indicating that a DNS lookup operation failed.
///
/// This exception is thrown when a DNS query returns a non-zero status code
/// or when the DNS resolution fails for other reasons.
class DNSLookupException extends DNSolveException {
  const DNSLookupException(this.message, [this.statusCode]);

  /// A human-readable error message describing the DNS lookup failure.
  final String message;

  /// The DNS status code, if available.
  final int? statusCode;

  @override
  String toString() => statusCode != null
      ? 'DNSLookupException: $message (Status: $statusCode)'
      : 'DNSLookupException: $message';
}

/// An exception indicating that a network error occurred during DNS resolution.
///
/// This exception is thrown when network connectivity issues prevent DNS queries.
class NetworkException extends DNSolveException {
  const NetworkException(this.message, [this.originalError]);

  /// A human-readable error message describing the network error.
  final String message;

  /// The original error that caused this exception, if available.
  final Object? originalError;

  @override
  String toString() => originalError != null
      ? 'NetworkException: $message (Original: $originalError)'
      : 'NetworkException: $message';
}

/// An exception indicating that a DNS query timed out.
///
/// This exception is thrown when a DNS query exceeds the specified timeout duration.
class TimeoutException extends DNSolveException {
  const TimeoutException(this.message, [this.timeout]);

  /// A human-readable error message describing the timeout.
  final String message;

  /// The timeout duration that was exceeded, if available.
  final Duration? timeout;

  @override
  String toString() => timeout != null
      ? 'TimeoutException: $message (Timeout: ${timeout!.inSeconds}s)'
      : 'TimeoutException: $message';
}

/// An exception indicating that an invalid domain name or IP address was provided.
///
/// This exception is thrown when input validation fails for domain names or IP addresses.
class InvalidDomainException extends DNSolveException {
  const InvalidDomainException(this.message, [this.input]);

  /// A human-readable error message describing the validation failure.
  final String message;

  /// The invalid input that caused this exception, if available.
  final String? input;

  @override
  String toString() => input != null
      ? 'InvalidDomainException: $message (Input: $input)'
      : 'InvalidDomainException: $message';
}

/// An exception indicating that the native FFI library could not be loaded
/// or a native function call failed.
///
/// This exception is thrown when there are issues with the native DNS resolver
/// library (e.g., missing library file, symbol lookup failure).
class NativeException extends DNSolveException {
  const NativeException(this.message, [this.originalError]);

  /// A human-readable error message describing the native error.
  final String message;

  /// The original error that caused this exception, if available.
  final Object? originalError;

  @override
  String toString() => originalError != null
      ? 'NativeException: $message (Original: $originalError)'
      : 'NativeException: $message';
}
