import 'package:flutter_test/flutter_test.dart';
import 'package:danaya_plus/features/assistant/application/voice_service.dart';

void main() {
  group('Voice amount expansion tests', () {
    test('Should expand values <= 10.0 to millions', () {
      expect(VoiceService.expandVoiceAmount(3.0), equals(3000000.0));
      expect(VoiceService.expandVoiceAmount(1.5), equals(1500000.0));
      expect(VoiceService.expandVoiceAmount(0.5), equals(500000.0));
    });

    test('Should expand values between 10.0 and 100.0 to thousands', () {
      expect(VoiceService.expandVoiceAmount(50.0), equals(50000.0));
      expect(VoiceService.expandVoiceAmount(25.0), equals(25000.0));
      expect(VoiceService.expandVoiceAmount(99.0), equals(99000.0));
    });

    test('Should preserve values >= 100.0 without reference total', () {
      expect(VoiceService.expandVoiceAmount(150.0), equals(150.0));
      expect(VoiceService.expandVoiceAmount(500.0), equals(500.0));
      expect(VoiceService.expandVoiceAmount(1500.0), equals(1500.0));
    });

    test('Should expand with referenceTotal when value aligns', () {
      // 500 spoken, reference is 500k -> should expand to 500k
      expect(VoiceService.expandVoiceAmount(500.0, referenceTotal: 500000.0), equals(500000.0));
      
      // 500 spoken, reference is 5k -> should expand to 500 (since 500 * 1000 != 5000)
      expect(VoiceService.expandVoiceAmount(500.0, referenceTotal: 5000.0), equals(500.0));

      // 1.5 spoken, reference is 1.5M -> should expand to 1.5M
      expect(VoiceService.expandVoiceAmount(1.5, referenceTotal: 1500000.0), equals(1500000.0));

      // 1500 spoken, reference is 1.5M -> should expand to 1.5M (1500 * 1000 = 1500000)
      expect(VoiceService.expandVoiceAmount(1500.0, referenceTotal: 1500000.0), equals(1500000.0));
    });
  });
}
