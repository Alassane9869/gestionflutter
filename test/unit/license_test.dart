import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:danaya_plus/features/license/domain/license_service.dart';

void main() {
  // Initialiser l'environnement de test Flutter
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LicenseService Reinforced Logic Tests', () {
    late LicenseService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = LicenseService();
    });

    test('Should retrieve a valid hardware ID format (16 Hex characters)', () async {
      final hid = await service.getHardwareId();
      expect(hid.length, 16);
      expect(hid, matches(RegExp(r'^[0-9A-F]{16}$')));
    });

    test('Should generate a 32-character key matching the transposition matrix', () async {
      final hid = await service.getHardwareId();
      final key = service.generateLicenseKey(hid, 'INF');
      
      expect(key.length, 32);
      expect(key, matches(RegExp(r'^[0-9A-Z]{32}$')));
    });

    test('Should successfully activate and validate key for INF (Unlimited)', () async {
      final hid = await service.getHardwareId();
      final key = service.generateLicenseKey(hid, 'INF');

      final success = await service.activateApp(key);
      expect(success, isTrue);

      final isActivated = await service.isAppActivated();
      expect(isActivated, isTrue);

      final days = await service.getDaysRemaining();
      expect(days, equals(9999));
    });

    test('Should successfully activate and validate key for Y1 (1 Year)', () async {
      final hid = await service.getHardwareId();
      final key = service.generateLicenseKey(hid, 'Y1');

      final success = await service.activateApp(key);
      expect(success, isTrue);

      final isActivated = await service.isAppActivated();
      expect(isActivated, isTrue);

      final days = await service.getDaysRemaining();
      expect(days, isNotNull);
      expect(days, greaterThanOrEqualTo(360));
      expect(days, lessThanOrEqualTo(366));
    });

    test('Should fail activation if the key is generated for another Hardware ID', () async {
      final key = service.generateLicenseKey('1122334455667788', 'Y1');

      final success = await service.activateApp(key);
      expect(success, isFalse);

      final isActivated = await service.isAppActivated();
      expect(isActivated, isFalse);
    });

    test('Should fail activation on corrupted keys or wrong lengths', () async {
      final successCorrupted = await service.activateApp('CORRUPTED-KEY-1234');
      expect(successCorrupted, isFalse);
    });
  });
}
