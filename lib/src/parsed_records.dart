part of 'dnsolve.dart';

/// Represents a parsed MX (Mail Exchange) record.
class MXRecord {
  const MXRecord({
    required this.priority,
    required this.exchange,
    required this.fqdn,
  });

  /// The priority of this MX record (lower is preferred).
  final int priority;

  /// The mail exchange hostname.
  final String exchange;

  /// Fully Qualified Domain Name.
  final String fqdn;

  @override
  String toString() => 'MXRecord(priority: $priority, exchange: $exchange)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MXRecord &&
        other.priority == priority &&
        other.exchange == exchange;
  }

  @override
  int get hashCode => Object.hash(priority, exchange);
}

/// Represents a parsed CAA (Certificate Authority Authorization) record.
class CAARecord {
  const CAARecord({
    required this.flags,
    required this.tag,
    required this.value,
    required this.fqdn,
  });

  /// The flags byte (typically 0).
  final int flags;

  /// The tag (e.g., "issue", "issuewild", "iodef").
  final String tag;

  /// The value associated with the tag.
  final String value;

  /// Fully Qualified Domain Name.
  final String fqdn;

  @override
  String toString() => 'CAARecord(flags: $flags, tag: $tag, value: $value)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CAARecord &&
        other.flags == flags &&
        other.tag == tag &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(flags, tag, value);
}

/// Represents a parsed SOA (Start of Authority) record.
class SOARecord {
  const SOARecord({
    required this.mname,
    required this.rname,
    required this.serial,
    required this.refresh,
    required this.retry,
    required this.expire,
    required this.minimum,
    required this.fqdn,
  });

  /// The primary name server.
  final String mname;

  /// The email address of the administrator (with @ replaced by .).
  final String rname;

  /// The serial number of the zone.
  final int serial;

  /// The refresh interval in seconds.
  final int refresh;

  /// The retry interval in seconds.
  final int retry;

  /// The expire time in seconds.
  final int expire;

  /// The minimum TTL in seconds.
  final int minimum;

  /// Fully Qualified Domain Name.
  final String fqdn;

  @override
  String toString() =>
      'SOARecord(mname: $mname, rname: $rname, serial: $serial)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SOARecord &&
        other.mname == mname &&
        other.rname == rname &&
        other.serial == serial;
  }

  @override
  int get hashCode => Object.hash(mname, rname, serial);
}

/// Represents a parsed TXT record with structured data.
class TXTRecord {
  const TXTRecord({
    required this.text,
    required this.fqdn,
  });

  /// The text content of the TXT record.
  final String text;

  /// Fully Qualified Domain Name.
  final String fqdn;

  @override
  String toString() => 'TXTRecord(text: $text)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TXTRecord && other.text == text;
  }

  @override
  int get hashCode => text.hashCode;
}
