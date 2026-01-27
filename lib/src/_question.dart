part of 'dnsolve.dart';

/// Represents a DNS question with a domain name and record type.
class Question {
  const Question({required this.name, required this.rType});

  /// The domain name being queried.
  final String? name;

  /// The DNS record type being queried.
  final RecordType? rType;

  factory Question.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const Question(name: null, rType: null);
    }

    return Question(
      name: json['name'] as String,
      rType: DNSolve.intToRecord(json['type'] as int),
    );
  }

  @override
  String toString() => '''(name: $name, rType: $rType)''';
}
