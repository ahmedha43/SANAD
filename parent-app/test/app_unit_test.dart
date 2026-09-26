import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parent_app/core/constants/api_constants.dart';
import 'package:parent_app/core/theme/app_theme.dart';

void main() {
  group('Parent App Core Tests', () {
    test('ApiConstants builds correct endpoints for LAN IP', () {
      ApiConstants.baseUrl = 'http://192.168.88.54:8080';
      expect(ApiConstants.loginUrl, 'http://192.168.88.54:8080/api/v1/auth/login');
      expect(ApiConstants.pairCodeUrl('child-123'), 'http://192.168.88.54:8080/api/v1/devices/children/child-123/pair-code');
      expect(ApiConstants.commandUrl('dev-456'), 'http://192.168.88.54:8080/api/v1/devices/dev-456/command');
    });

    test('AppTheme loads darkTheme without errors', () {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, equals(Brightness.dark));
    });

    test('WebSocket Telemetry packet parsing', () {
      const sampleJson = '''
      {
        "type": "LOCATION_UPDATE",
        "id": "msg-123",
        "from": "dev-001",
        "timestamp": 1758202361000,
        "payload": {
          "latitude": 24.7136,
          "longitude": 46.6753,
          "accuracy": 4.5
        }
      }
      ''';

      final decoded = jsonDecode(sampleJson) as Map<String, dynamic>;
      expect(decoded['type'], equals('LOCATION_UPDATE'));
      expect(decoded['from'], equals('dev-001'));
      expect(decoded['payload']['latitude'], equals(24.7136));
    });
  });
}
