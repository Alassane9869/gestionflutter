import 'package:danaya_plus/features/assistant/application/nlp_engine.dart';

void main() {
  final result = NlpEngine.analyze("change le nom du boutique en DANAYA+");
  // ignore: avoid_print
  print(result.toString());
}
