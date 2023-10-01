# DNSolve

[![License: MIT][license_badge]][license_link]

DNSolve is a Dart library that provides an easy way to perform DNS lookups. It supports both forward and reverse DNS lookups, and can be used with different DNS providers.

## Installation

To install DNSolve, add the following dependency to your `pubspec.yaml` file:

```dart
dependencies:
  dnsolve: ^0.6.0
```

### Usage

To perform a DNS lookup, you can use the `lookup()` method. This method takes the following parameters:

- `domain`: The domain to lookup.
- `dnsSec`: Whether to enable DNSSEC (Domain Name System Security Extensions).
- `type`: The DNS record type to look up.
- `provider`: The DNS provider to use.

The following code snippet shows how to perform a DNS lookup for the domain `example.com`:

```dart
import 'dart:developer';

import 'package:dnsolve/dnsolve.dart';

Future<void> main() async {
  final dnsolve = DNSolve();
  final response = await dnsolve.lookup(
    '_xmpp._tcp.vsevex.me',
    dnsSec: true,
    type: RecordType.srv,
  );

  if (response.answer!.records != null) {
    for (final record in response.answer!.records!) {
      log(record.toBind);
    }
  }
}
```

The output will be something like this:

```bash
_xmpp._tcp.vsevex.me. 1805 IN SRV "0 5 1234 xmpp-client.vsevex.me."
_xmpp._tcp.vsevex.me. 1805 IN SRV "1 5 1234 xmpp-client.vsevex.me."
```

The `lookup()` method returns a `ResolveResponse` object. This object contains the following properties:

- `status`: The status of the DNS lookup.
- `answer`: The DNS answer.
- Some other additional properties.

The `answer` property contains a list of `Record` objects. Each `Record` object represents a single DNS record. The `Record` object has the following properties:

- `name`: The name of the DNS record.
- `rType`: The type of the DNS record.
- `ttl`: The time to live of the DNS record.
- `data`: The data of the DNS record.

## Contributing to DNSolve

I do welcome and appreciate contributions from the community to enhance the `DNSolve`. If you have any improvements, bug fixes, or new features to contribute, you can do so by creating a pull request.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
