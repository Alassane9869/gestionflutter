// ignore_for_file: avoid_print
import 'package:danaya_plus/features/assistant/application/nlp_engine.dart';

void main() {
  try {
    print("Testing NlpEngine...");
    
    // Test 1: Titan Capability
    final r1 = NlpEngine.analyze("que sais tu faire");
    print("Test 1 - Capability: ${r1.intent}");
    
    // Test 2: Theme Query
    final r2 = NlpEngine.analyze("combien de mode");
    print("Test 2 - Theme Query: ${r2.intent}");
    
    // Test 3: Standard Sale
    final r3 = NlpEngine.analyze("vends 3 coca");
    print("Test 3 - Sale: ${r3.intent}");

    // Test 4: New Client
    final r4 = NlpEngine.analyze("ajoute un client Alpha");
    print("Test 4 - Client: ${r4.intent}");

    print("All tests completed successfully.");
  } catch (e, st) {
    print("FATAL ERROR IN NLP ENGINE:");
    print(e);
    print(st);
  }
}
