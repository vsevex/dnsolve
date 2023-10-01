part of 'dnsolve.dart';

String _handleResponse(http.Response response) {
  if (response.statusCode >= 200 && response.statusCode <= 209) {
    return response.body;
  } else {
    throw ResponseException(
      body: response.body,
      headers: response.headers,
      statusCode: response.statusCode,
    );
  }
}

/// Represents a response from a DNS resolution operation.
///
/// This class includes information about the resolution status, flags,
/// comments, resolved answer, and the list of questions queried.
class ResolveResponse {
  const ResolveResponse({
    required this.status,
    required this.tc,
    required this.rd,
    required this.ra,
    required this.ad,
    required this.cd,
    required this.comment,
    required this.answer,
    required this.questions,
  });

  /// The status code indicating the result of the DNS resolution.
  final int? status;

  /// Indicates if the response was truncated.
  final bool? tc;

  /// Indicates if recursion was desired in the request.
  final bool? rd;

  /// Indicates if recursion is available in the response.
  final bool? ra;

  /// Indicates if the data in the response is authenticated.
  final bool? ad;

  /// Indicates if checking is disabled in the response.
  final bool? cd;

  /// Additional comments or information related to the resolution response.
  final String? comment;

  /// The resolved answer containing DNS records.
  final _Answer? answer;

  /// List of questions queried in the resolution request.
  final List<_Question>? questions;

  /// Constructs a [ResolveResponse] instance from JSON data.
  ///
  /// The [json] parameter should be a map containing the fields of a DNS
  /// resolution response. Returns a [ResolveResponse] instance with parsed
  /// data.
  factory ResolveResponse.fromJson(Map<String, dynamic> json) =>
      ResolveResponse(
        status: json['Status'] as int?,
        tc: json['TC'] as bool?,
        rd: json['RD'] as bool?,
        ra: json['RA'] as bool?,
        ad: json['AD'] as bool?,
        cd: json['CD'] as bool?,
        comment: json['comment'] as String?,
        answer: _Answer.fromJson(json['Answer'] as List<dynamic>?),
        questions: json['Question'] == null
            ? null
            : (json['Question'] as List<dynamic>)
                .map(
                  (question) =>
                      _Question.fromJson(question as Map<String, dynamic>),
                )
                .toList(),
      );

  @override
  String toString() =>
      '''status: $status, truncation: $tc, recursion desired(rd): $rd, recursion available(ra): $ra, authenticated data(ad): $ad, checking disabled(cd): $cd, comment: $comment, answer: $answer, questions: $questions''';
}
