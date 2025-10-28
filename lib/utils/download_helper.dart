// lib/utils/download_helper.dart
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

export 'download_helper_web.dart' if (dart.library.html) 'download_helper_web.dart';
import 'download_helper_web.dart' 
    show downloadBytesWeb;
    
abstract class DownloadHelper {
  static Future<void> saveBytes(String filename, Uint8List bytes) async {
    if (kIsWeb) {
      await downloadBytesWeb(filename, bytes);
    } else {
      // TODO: implement mobile/desktop saving via path_provider if needed
      throw UnimplementedError('Download not implemented on this platform');
    }
  }
}
