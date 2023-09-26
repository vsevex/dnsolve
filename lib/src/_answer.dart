part of 'dnsolve.dart';

class _Answer {
  const _Answer(this.records);

  final List<_Record>? records;

  factory _Answer.fromJson(List<dynamic>? json) {
    if (json == null) {
      return const _Answer(null);
    }

    return _Answer(
      json
          .map((answer) => _Record.fromJson(answer as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() => '''answer($records)''';
}

class _Record {
  const _Record({
    required this.name,
    required this.rType,
    required this.ttl,
    required this.data,
  });

  final String name;
  final RecordType rType;
  final int ttl;
  final String data;

  factory _Record.fromJson(Map<String, dynamic> json) => _Record(
        name: json['name'] as String,
        rType: DNSolve.intToRecord(json['type'] as int),
        ttl: json['TTL'] as int,
        data: json['data'] as String,
      );

  @override
  String toString() => '''name: $name, type: $rType, ttl: $ttl, data: $data''';

  String get toBind {
    final buffer = StringBuffer();
    buffer.write(name);
    if (buffer.length < 8) {
      buffer.write('\t');
    }
    if (buffer.length > 10) {
      buffer.write('\t');
    }
    buffer.writeAll(
      [ttl, '\tIN\t', rType.name.toUpperCase(), '\t', '"', data, '"'],
    );

    return buffer.toString();
  }
}
