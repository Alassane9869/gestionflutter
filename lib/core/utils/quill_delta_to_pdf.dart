import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class QuillDeltaToPdf {
  static List<pw.Widget> convert(
    List<dynamic> deltaJson,
    pw.Font? font,
    pw.Font? fontBold, {
    Map<String, String>? variables,
    PdfColor? accentColor,
  }) {
    List<pw.Widget> widgets = [];
    
    // We group inserts until a newline
    List<pw.TextSpan> currentLineSpans = [];
    
    for (var op in deltaJson) {
      if (op['insert'] is String) {
        String text = op['insert'];
        if (variables != null) {
          variables.forEach((key, val) {
            text = text.replaceAll('[$key]', val);
          });
        }
        Map<String, dynamic> attrs = op['attributes'] ?? {};
        
        // Handle newlines which define the block style
        if (text == '\n') {
          // Block level attributes
          int? header = attrs['header'];
          pw.TextAlign align = pw.TextAlign.left;
          if (attrs['align'] == 'center') align = pw.TextAlign.center;
          if (attrs['align'] == 'right') align = pw.TextAlign.right;
          if (attrs['align'] == 'justify') align = pw.TextAlign.justify;
          
          double fontSize = 9.5; // Base font size
          pw.Font? currentFont = font;
          PdfColor textColor = PdfColors.black;
          pw.EdgeInsets margin = const pw.EdgeInsets.only(bottom: 6);

          if (header == 1) { 
            fontSize = 14; 
            currentFont = fontBold; 
            textColor = accentColor ?? PdfColors.blueGrey900;
            margin = const pw.EdgeInsets.only(bottom: 16, top: 10);
          } else if (header == 2) { 
            fontSize = 11; 
            currentFont = fontBold; 
            textColor = accentColor ?? PdfColors.blueGrey800;
            margin = const pw.EdgeInsets.only(bottom: 8, top: 6);
          } else if (header == 3) { 
            fontSize = 10; 
            currentFont = fontBold; 
            margin = const pw.EdgeInsets.only(bottom: 6, top: 4);
          }
          
          widgets.add(
            pw.Container(
              margin: margin,
              alignment: align == pw.TextAlign.center ? pw.Alignment.center : 
                         align == pw.TextAlign.right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              child: pw.RichText(
                textAlign: align == pw.TextAlign.left ? pw.TextAlign.justify : align, // Default to justify for normal text
                text: pw.TextSpan(
                  children: currentLineSpans,
                  style: pw.TextStyle(
                    font: currentFont, 
                    fontSize: fontSize, 
                    color: textColor,
                    lineSpacing: 1.5,
                    decoration: header == 2 ? pw.TextDecoration.underline : pw.TextDecoration.none,
                  ),
                ),
              ),
            )
          );
          currentLineSpans = [];
        } else {
          // Split by newline if text contains newline
          List<String> lines = text.split('\n');
          for (int i = 0; i < lines.length; i++) {
            if (lines[i].isNotEmpty) {
              bool isBold = attrs['bold'] == true;
              bool isItalic = attrs['italic'] == true;
              
              currentLineSpans.add(pw.TextSpan(
                text: lines[i],
                style: pw.TextStyle(
                  font: isBold ? fontBold : (isItalic ? font : font),
                  fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
                  fontSize: 9.5, // Match base font size
                  color: isBold ? PdfColors.grey900 : PdfColors.black,
                )
              ));
            }
            if (i < lines.length - 1) {
              // Flush current line
              widgets.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.RichText(
                    textAlign: pw.TextAlign.justify,
                    text: pw.TextSpan(
                      children: currentLineSpans,
                      style: const pw.TextStyle(lineSpacing: 1.5)
                    )
                  )
                )
              );
              currentLineSpans = [];
            }
          }
        }
      }
    }
    
    // Add any remaining
    if (currentLineSpans.isNotEmpty) {
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          child: pw.RichText(
            textAlign: pw.TextAlign.justify,
            text: pw.TextSpan(
              children: currentLineSpans,
              style: const pw.TextStyle(lineSpacing: 1.5)
            )
          )
        )
      );
    }
    
    return widgets;
  }
}
