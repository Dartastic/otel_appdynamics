// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_appdynamics/otel_appdynamics.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemoryLogExporter logs;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_appdynamics-test',
    );
    logs = harness.logs;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(LogRecord r) {
    final list = r.attributes?.toList() ?? <Attribute<Object>>[];
    return {for (final a in list) a.key: a.value};
  }

  test('customEvent records INFO log', () async {
    OTelAppdynamics(applicationKey: 'AD-KEY-1')
        .customEvent('cart_added', properties: {'sku': 'S-1'});
    await harness.flushLogs();
    final r = logs.records
        .firstWhere((r) => r.body == 'appdynamics.event cart_added');
    final a = attrsOf(r);
    expect(a['appdynamics.event.name'], 'cart_added');
    expect(a['appdynamics.application.key'], 'AD-KEY-1');
    expect(a['appdynamics.property.sku'], 'S-1');
  });

  test('reportError uses ERROR severity', () async {
    OTelAppdynamics().reportError('boom');
    await harness.flushLogs();
    final r =
        logs.records.firstWhere((r) => r.body == 'appdynamics.error boom');
    expect(r.severityNumber, Severity.ERROR);
  });

  test('suppression skips emit but forwards', () async {
    var forwarded = 0;
    await runWithoutAppdynamicsInstrumentationAsync(() async {
      OTelAppdynamics(forwardCustomEvent: (_, __) => forwarded++)
          .customEvent('x');
    });
    await harness.flushLogs();
    expect(forwarded, 1);
    expect(
      logs.records.where((r) => r.body == 'appdynamics.event x'),
      isEmpty,
    );
  });
}
