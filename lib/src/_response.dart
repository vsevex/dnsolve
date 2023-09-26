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

  final int? status;
  final bool? tc;
  final bool? rd;
  final bool? ra;
  final bool? ad;
  final bool? cd;
  final String? comment;
  final _Answer? answer;
  final List<_Question>? questions;

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
