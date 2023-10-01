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
