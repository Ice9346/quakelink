import 'package:flutter_test/flutter_test.dart';
import 'package:quakelink_app/config/app_config.dart';

void main() {
  test('default WebSocket URL follows API URL', () {
    expect(AppConfig.apiBaseUrl, 'http://127.0.0.1:8080');
    expect(AppConfig.wsBaseUrl, 'ws://127.0.0.1:8080');
  });
}
