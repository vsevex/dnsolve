/// Represents an [Exception] that occured while processing an DNS request.
///
/// It contains information about the status code, headers, and body of the
/// response.
class ResponseException implements Exception {
  const ResponseException({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

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
