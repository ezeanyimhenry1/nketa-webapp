import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

class ImageExport {
  static Future<bool> requestGalleryAccess() async => true;

  static Future<void> savePng(Uint8List bytes, String filename) async {
    await sharePng(bytes, filename);
  }

  static Future<void> sharePng(
    Uint8List bytes,
    String filename, {
    String? text,
    String? subject,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'image/png', name: filename),
        ],
        text: text,
        subject: subject,
      ),
    );
  }
}
