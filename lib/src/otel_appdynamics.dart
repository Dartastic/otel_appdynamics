// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_appdynamics_suppression.dart';

const _loggerName = 'package.appdynamics';

/// Bridges AppDynamics Mobile / Browser SDK calls (custom events,
/// reportError, identify) into OpenTelemetry log records.
class OTelAppdynamics {
  OTelAppdynamics({
    APILoggerProvider? loggerProvider,
    this.applicationKey,
    this.forwardCustomEvent,
    this.forwardSetUser,
    this.forwardReportError,
  }) : _loggerProvider = loggerProvider;

  final APILoggerProvider? _loggerProvider;
  final String? applicationKey;
  final void Function(String name, Map<String, Object?>? props)?
      forwardCustomEvent;
  final void Function(String userData)? forwardSetUser;
  final void Function(String message)? forwardReportError;

  APILogger _logger() =>
      (_loggerProvider ?? OTelAPI.loggerProvider()).getLogger(_loggerName);

  void customEvent(String name, {Map<String, Object?>? properties}) {
    forwardCustomEvent?.call(name, properties);
    if (appdynamicsInstrumentationSuppressed()) return;
    _emit(
      body: 'appdynamics.event $name',
      eventType: 'custom_event',
      severity: Severity.INFO,
      attrs: [OTelAPI.attributeString('appdynamics.event.name', name)],
      flatPrefix: 'appdynamics.property.',
      payload: properties,
    );
  }

  void setUser(String userData) {
    forwardSetUser?.call(userData);
    if (appdynamicsInstrumentationSuppressed()) return;
    _emit(
      body: 'appdynamics.set_user $userData',
      eventType: 'set_user',
      severity: Severity.INFO,
      attrs: [
        OTelAPI.attributeString('appdynamics.user.data', userData),
        OTelAPI.attributeString(User.userId.key, userData),
      ],
    );
  }

  void reportError(String message) {
    forwardReportError?.call(message);
    if (appdynamicsInstrumentationSuppressed()) return;
    _emit(
      body: 'appdynamics.error $message',
      eventType: 'error',
      severity: Severity.ERROR,
      attrs: [OTelAPI.attributeString('appdynamics.error.message', message)],
    );
  }

  void _emit({
    required String body,
    required String eventType,
    required Severity severity,
    required List<Attribute<Object>> attrs,
    String? flatPrefix,
    Map<String, Object?>? payload,
  }) {
    final all = <Attribute<Object>>[
      OTelAPI.attributeString('appdynamics.event.type', eventType),
      if (applicationKey != null)
        OTelAPI.attributeString('appdynamics.application.key', applicationKey!),
      ...attrs,
    ];
    if (payload != null && flatPrefix != null) {
      payload.forEach((k, v) {
        if (v == null) return;
        final key = '$flatPrefix$k';
        if (v is String) {
          all.add(OTelAPI.attributeString(key, v));
        } else if (v is int) {
          all.add(OTelAPI.attributeInt(key, v));
        } else if (v is double) {
          all.add(OTelAPI.attributeDouble(key, v));
        } else if (v is bool) {
          all.add(OTelAPI.attributeBool(key, v));
        } else {
          all.add(OTelAPI.attributeString(key, v.toString()));
        }
      });
    }
    _logger().emit(
      severityNumber: severity,
      severityText: severity == Severity.ERROR ? 'error' : 'info',
      body: body,
      attributes: OTelAPI.attributes(all),
    );
  }
}
