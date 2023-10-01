part of 'dnsolve.dart';

/// Represents an answer containing a list of generic records and a list of
/// Service (SRV) records parsed from JSON data.
class _Answer {
  const _Answer(this.records, [this.srvs]);

  /// List of generic records.
  final List<_Record>? records;

  /// List of Service (SRV) records.
  final List<SRVRecord>? srvs;

  /// Constructs an [_Answer] instance from JSON data.
  ///
  /// The [json] parameter should be a list of dynamic objects representing
  /// DNS records. Returns an [_Answer] instance containing parsed records
  /// and Service (SRV) records.
  factory _Answer.fromJson(List<dynamic>? json) {
    if (json == null) {
      return const _Answer(null);
    }

    final records = json
        .map((answer) => _Record.fromJson(answer as Map<String, dynamic>))
        .toList();
    final srvs = <SRVRecord>[];

    {
      final RegExp regExp = RegExp(r'(\d+)\s+(\d+)\s+(\d+)\s+([\w\.\-]+)');
      for (final record in records) {
        if (record.rType == RecordType.srv) {
          final match = regExp.firstMatch(record.data);

          if (match != null) {
            final priority = int.parse(match.group(1)!);
            final weight = int.parse(match.group(2)!);
            final port = int.parse(match.group(3)!);
            final target = match.group(4)!;

            srvs.add(
              SRVRecord(
                priority: priority,
                weight: weight,
                port: port,
                target: target,
                fqdn: record.name,
              ),
            );
          } else {
            throw const SRVRecordFormatException(
              'Failed to parse or process the Service (SRV) record',
            );
          }
        }
      }
    }

    return _Answer(records, srvs);
  }

  @override
  String toString() => '''$records''';
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
  String toString() =>
      '''(name: $name, type: $rType, ttl: $ttl, data: $data)''';

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

/// Returns a Service (SRV) record containing information about a server or
/// service in the domain name system (DNS).
class SRVRecord {
  /// Constructs an [SRVRecord] with the specified parameters.
  const SRVRecord({
    required this.priority,
    required this.weight,
    required this.port,
    this.target,
    required this.fqdn,
  });

  /// The priority of this SRV record.
  final int priority;

  /// The weight of this SRV record.
  final int weight;

  /// The port on which the service is available.
  final int port;

  /// The target domain name of the server.
  final String? target;

  /// Fully Qualified Domain Name.
  final String fqdn;

  /// Sorts a list of [SRVRecord] instances based on their priority and weight.
  static List<SRVRecord> sort(List<SRVRecord> records) {
    records.sort(_srvRecordSortComparator);

    return records;
  }

  /// Comparator function for sorting [SRVRecord] instances.
  static int _srvRecordSortComparator(SRVRecord a, SRVRecord b) {
    if (a.priority < b.priority) {
      return -1;
    } else {
      if (a.priority > b.priority) {
        return 1;
      }

      if (a.weight < b.weight) {
        return -1;
      } else if (a.weight > b.weight) {
        return 1;
      } else {
        return 0;
      }
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is SRVRecord &&
        other.runtimeType == runtimeType &&
        other.priority == priority &&
        other.weight == weight &&
        other.port == port &&
        other.target == other.target;
  }

  @override
  int get hashCode => Object.hash(priority, weight, port, target);
}
