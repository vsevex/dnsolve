part of 'dnsolve.dart';

class _Question {
  const _Question({required this.name, required this.rType});

  final String? name;
  final RecordType? rType;

  factory _Question.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const _Question(name: null, rType: null);
    }

    return _Question(
      name: json['name'] as String,
      rType: DNSolve.intToRecord(json['type'] as int),
    );
  }

  @override
  String toString() => '''(name: $name, rType: $rType)''';
}
