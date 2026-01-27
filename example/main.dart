import 'dart:developer';

import 'package:dnsolve/dnsolve.dart';

Future<void> main() async {
  final dnsolve = DNSolve();

  try {
    final response = await dnsolve.lookup(
      '_xmpp._tcp.vsevex.me',
      dnsSec: true,
      type: RecordType.srv,
      timeout: const Duration(seconds: 10),
    );

    if (response.answer?.records != null) {
      for (final record in response.answer!.records!) {
        log(record.toBind);
      }
    }

    // Access parsed SRV records
    if (response.answer?.srvs != null) {
      log('Parsed SRV Records:');
      for (final srv in response.answer!.srvs!) {
        log('  Priority: ${srv.priority}, Weight: ${srv.weight}, '
            'Port: ${srv.port}, Target: ${srv.target}');
      }
    }
  } on DNSolveException catch (e) {
    log('DNS error: $e');
  } finally {
    dnsolve.dispose();
  }
}
