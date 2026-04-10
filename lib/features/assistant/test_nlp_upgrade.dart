// ignore_for_file: avoid_print
import 'package:danaya_plus/features/assistant/application/nlp_engine.dart';
import 'package:danaya_plus/features/assistant/domain/assistant_models.dart';

void main() {
  print('🧪 --- STARTING TITAN V4 NLP VERIFICATION --- 🧪\n');

  final testCases = [
    {
      'input': 'change le theme en bleu',
      'expected': 'themeColorChange',
    },
    {
      'input': 'mets la couleur rouge',
      'expected': 'themeColorChange',
    },
    {
      'input': 'bascule en mode sombre',
      'expected': 'themeDark',
    },
    {
      'input': 'dis-moi, combien ya de clients debiteurs actuellement ?',
      'expected': 'clientDebtList',
    },
    {
      'input': 'est-ce que tu peux me donner le bilan de la journée stp ?',
      'expected': 'salesQuery',
    },
  ];

  int passed = 0;
  for (final test in testCases) {
    final input = test['input'] as String;
    final expected = test['expected'] as String;
    final context = (test['context'] as AssistantContext?) ?? AssistantContext.general;

    final result = NlpEngine.analyze(input, context: context);
    final success = result.intent.name == expected;

    if (success) {
      print('✅ [PASS] "$input" -> ${result.intent.name}');
      passed++;
    } else {
      print('❌ [FAIL] "$input"');
      print('   -> Attendu: $expected');
      print('   -> Obtenu:  ${result.intent.name} (Conf: ${result.confidence.toStringAsFixed(2)})');
    }
  }

  print('\n📊 Résultat : $passed/${testCases.length} tests réussis.');
  
  if (passed == testCases.length) {
    print('\n🚀 TITAN V4 ENGINE IS STABLE AND READY! 🚀');
  } else {
    print('\n⚠️ Some adjustments might be needed in synonym weights or context boosts.');
  }
}
