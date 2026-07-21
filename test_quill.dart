// ignore_for_file: avoid_print
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';

void main() {
  String html = '''
  <h1>CDI CLASSIQUE</h1>
  <br>
  <p>Paragraph 1</p>
  <p>Paragraph 2</p>
  <br>
  <p>Paragraph 3</p>
  ''';

  String sanitized = html
      .replaceAll(RegExp(r'(?<=</(?:p|div)>)\s*(?!<br\s*/?>)'), '<br>')
      .replaceAll(RegExp(r'<br\s*/?>(\s*<br\s*/?>)+'), '<br>');
  
  print('Sanitized HTML:');
  print(sanitized);

  final delta = HtmlToDelta().convert(sanitized);
  print('\nDELTA:');
  for (var op in delta.toJson()) {
    print(op);
  }
}
