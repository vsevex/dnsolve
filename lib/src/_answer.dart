part of 'dnsolve.dart';

/// Represents an answer containing a list of generic records and parsed
/// record types (SRV, MX, CAA, SOA, TXT).
class Answer {
  const Answer(
    this.records, [
    this.srvs,
    this.mxs,
    this.caas,
    this.soas,
    this.txts,
  ]);

  /// List of generic records.
  final List<Record>? records;

  /// List of Service (SRV) records.
  final List<SRVRecord>? srvs;

  /// List of Mail Exchange (MX) records.
  final List<MXRecord>? mxs;

  /// List of Certificate Authority Authorization (CAA) records.
  final List<CAARecord>? caas;

  /// List of Start of Authority (SOA) records.
  final List<SOARecord>? soas;

  /// List of Text (TXT) records.
  final List<TXTRecord>? txts;

  /// Constructs an [Answer] instance from JSON data.
  ///
  /// The [json] parameter should be a list of dynamic objects representing
  /// DNS records. Returns an [Answer] instance containing parsed records
  /// and Service (SRV) records.
  factory Answer.fromJson(List<dynamic>? json) {
    if (json == null) {
      return const Answer(null);
    }

    final records = json
        .map((answer) => Record.fromJson(answer as Map<String, dynamic>))
        .toList();
    final srvs = <SRVRecord>[];
    final mxs = <MXRecord>[];
    final caas = <CAARecord>[];
    final soas = <SOARecord>[];
    final txts = <TXTRecord>[];

    // Parse SRV records
    {
      final regExp = RegExp(r'(\d+)\s+(\d+)\s+(\d+)\s+([\w\.\-]+)');
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

    // Parse MX records
    {
      final regExp = RegExp(r'(\d+)\s+([\w\.\-]+)');
      for (final record in records) {
        if (record.rType == RecordType.mx) {
          final match = regExp.firstMatch(record.data);
          if (match != null) {
            final priority = int.parse(match.group(1)!);
            final exchange = match.group(2)!;
            mxs.add(
              MXRecord(
                priority: priority,
                exchange: exchange,
                fqdn: record.name,
              ),
            );
          }
        }
      }
    }

    // Parse CAA records
    {
      final regExp = RegExp(r'(\d+)\s+(\w+)\s+"([^"]+)"');
      for (final record in records) {
        if (record.rType == RecordType.caa) {
          final match = regExp.firstMatch(record.data);
          if (match != null) {
            final flags = int.parse(match.group(1)!);
            final tag = match.group(2)!;
            final value = match.group(3)!;
            caas.add(
              CAARecord(
                flags: flags,
                tag: tag,
                value: value,
                fqdn: record.name,
              ),
            );
          }
        }
      }
    }

    // Parse SOA records
    {
      final regExp = RegExp(
        r'([\w\.\-]+)\s+([\w\.\-]+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
      );
      for (final record in records) {
        if (record.rType == RecordType.soa) {
          final match = regExp.firstMatch(record.data);
          if (match != null) {
            soas.add(
              SOARecord(
                mname: match.group(1)!,
                rname: match.group(2)!,
                serial: int.parse(match.group(3)!),
                refresh: int.parse(match.group(4)!),
                retry: int.parse(match.group(5)!),
                expire: int.parse(match.group(6)!),
                minimum: int.parse(match.group(7)!),
                fqdn: record.name,
              ),
            );
          }
        }
      }
    }

    // Parse TXT records
    {
      for (final record in records) {
        if (record.rType == RecordType.txt) {
          // Remove quotes if present
          final text = record.data.replaceAll(RegExp(r'^"|"$'), '');
          txts.add(
            TXTRecord(
              text: text,
              fqdn: record.name,
            ),
          );
        }
      }
    }

    return Answer(
      records,
      srvs.isEmpty ? null : srvs,
      mxs.isEmpty ? null : mxs,
      caas.isEmpty ? null : caas,
      soas.isEmpty ? null : soas,
      txts.isEmpty ? null : txts,
    );
  }

  @override
  String toString() => '''$records''';
}

/// Represents a DNS record with its name, type, TTL, and data.
class Record {
  const Record({
    required this.name,
    required this.rType,
    required this.ttl,
    required this.data,
  });

  final String name;
  final RecordType rType;
  final int ttl;
  final String data;

  factory Record.fromJson(Map<String, dynamic> json) => Record(
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
