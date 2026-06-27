import 'package:flutter_test/flutter_test.dart';
import 'package:danaya_plus/features/assistant/application/gemini_live_service.dart';

void main() {
  group('GeminiLiveService Unit Tests', () {
    test('Should initialize with correct default model and voiceName', () {
      final service = GeminiLiveService(apiKey: 'TEST_KEY');
      expect(service.apiKey, 'TEST_KEY');
      expect(service.model, 'gemini-3.1-flash-live-preview');
      expect(service.voiceName, 'Kore');
      expect(service.connectionState, LiveConnectionState.disconnected);
      expect(service.isSetupComplete, false);
    });

    test('Should allow custom model and voiceName during initialization', () {
      final service = GeminiLiveService(
        apiKey: 'TEST_KEY_2',
        model: 'gemini-3.5-live-translate-preview',
        voiceName: 'Puck',
      );
      expect(service.apiKey, 'TEST_KEY_2');
      expect(service.model, 'gemini-3.5-live-translate-preview');
      expect(service.voiceName, 'Puck');
    });
  });
}
