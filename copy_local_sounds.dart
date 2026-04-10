// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  final map = {
    'sale_success.wav': 'C:\\Windows\\Media\\tada.wav',
    'scan_success.wav': 'C:\\Windows\\Media\\chimes.wav',
    'error.wav': 'C:\\Windows\\Media\\Windows Background.wav',
    'stock_alert.wav': 'C:\\Windows\\Media\\Windows Error.wav',
    'session_start.wav': 'C:\\Windows\\Media\\Windows Startup.wav',
    'test.wav': 'C:\\Windows\\Media\\Windows Default.wav',
  };

  final dir = Directory('assets/sounds');
  if (!await dir.exists()) await dir.create(recursive: true);

  // Clear existing MP3s that failed
  await for (var entity in dir.list()) {
    if (entity is File && entity.path.endsWith('.mp3')) {
      await entity.delete();
    }
  }

  final fallback = File('C:\\Windows\\Media\\ding.wav');

  for (var entry in map.entries) {
    try {
      var source = File(entry.value);
      if (!await source.exists()) {
        source = fallback;
      }
      if (await source.exists()) {
        await source.copy('assets/sounds/${entry.key}');
        print('Copied to ${entry.key}');
      } else {
         print('Source not found for ${entry.key}');
      }
    } catch (e) {
      print('Failed ${entry.key}: $e');
    }
  }
}
