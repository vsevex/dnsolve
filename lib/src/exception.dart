/// An abstract class representing an exception related to DNS solving.
///
/// This serves as a base class for exceptions that may occur during DNS
/// resolution or parsing operations.
abstract class DNSolveException implements Exception {
  const DNSolveException();
}

/// Represents an [Exception] that occured while processing an DNS request.
///
/// It contains information about the status code, headers, and body of the
/// response.
class ResponseException extends DNSolveException {
  const ResponseException({
    required this.statusCode,
    required this.headers,
    required this.body,
  }) : super();

  /// The status code of the response.
  final int statusCode;

  /// The headers of the response.
  final Map<String, String> headers;

  /// The body of the response.
  final String body;

  @override
  String toString() =>
      '''Exception(Status Code: $statusCode, Response Headers: $headers, Response Body: $body)''';
}

/// An exception indicating that an error occurred while parsing or processing a
/// Service (SRV) record.
///
/// This is a specific type of [DNSolveException].
class SRVRecordFormatException extends DNSolveException {
  const SRVRecordFormatException(this.message);

  final String message;
}
