import 'dart:io';
import 'package:pdf/widgets.dart' as pw;

/// A singleton service to manage and cache PDF resources like fonts and logos.
/// Loading resources once and reusing them across documents significantly improves performance.
class PdfResourceService {
  PdfResourceService._internal();
  static final PdfResourceService instance = PdfResourceService._internal();

  // Font Cache
  pw.Font? _regular;
  pw.Font? _bold;
  pw.Font? _italic;
  
  
  // Image Cache
  final Map<String, pw.MemoryImage> _imageAssets = {};

  /// Loads standard regular font offline (Arial)
  pw.Font get regular {
    if (_regular == null) {
      try { _regular = pw.Font.ttf(File('C:/Windows/Fonts/arial.ttf').readAsBytesSync().buffer.asByteData()); }
      catch (_) { _regular = pw.Font.helvetica(); } // Fallback if not on Windows
    }
    return _regular!;
  }

  /// Loads standard bold font offline (Arial Bold)
  pw.Font get bold {
    if (_bold == null) {
      try { _bold = pw.Font.ttf(File('C:/Windows/Fonts/arialbd.ttf').readAsBytesSync().buffer.asByteData()); }
      catch (_) { _bold = pw.Font.helveticaBold(); }
    }
    return _bold!;
  }

  /// Loads standard italic font offline (Arial Italic)
  pw.Font get italic {
    if (_italic == null) {
      try { _italic = pw.Font.ttf(File('C:/Windows/Fonts/ariali.ttf').readAsBytesSync().buffer.asByteData()); }
      catch (_) { _italic = pw.Font.helveticaOblique(); }
    }
    return _italic!;
  }

  /// Ensures all core fonts are loaded into memory.
  Future<void> initFonts() async {
    // Fonts are now lazily loaded synchronously via getters
    // We can call them here to force load them if needed.
    preload();
  }

  /// Forces the loading of all core fonts into memory immediately.
  /// Call this at app startup or first service initialization.
  void preload() {
    // Accessing the getters triggers the lazy loading and caching
    regular; 
    bold;
    italic;
  }

  /// Loads a custom Font and caches it.
  Future<pw.Font> getCustomFont(String name, {bool isBold = false, bool isItalic = false}) async {
    if (isBold) return bold;
    if (isItalic) return italic;
    return regular;
  }

  /// Loads a local image file into memory and caches it.
  /// This prevents redundant disk I/O inside the PDF rendering tree.
  pw.MemoryImage? getLogo(String? path) {
    if (path == null || path.isEmpty) return null;
    
    if (_imageAssets.containsKey(path)) return _imageAssets[path];
    
    final file = File(path);
    if (file.existsSync()) {
      final image = pw.MemoryImage(file.readAsBytesSync());
      _imageAssets[path] = image;
      return image;
    }
    return null;
  }
  
  /// Clears the image cache (useful if the user changes their logo in settings).
  void clearImageCache() {
    _imageAssets.clear();
  }
}
