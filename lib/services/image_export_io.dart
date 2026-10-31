import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ImageExport {
  static Future<bool> requestGalleryAccess() async {
    var hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      await Gal.requestAccess();
      hasAccess = await Gal.hasAccess();
    }
    return hasAccess;
  }

  static Future<void> savePng(Uint8List bytes, String filename) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);
    try {
      await Gal.putImage(file.path, album: 'Nketa');
    } finally {
      Future<void>.delayed(const Duration(seconds: 5), () {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });
    }
  }

  static Future<void> sharePng(
    Uint8List bytes,
    String filename, {
    String? text,
    String? subject,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: text,
        subject: subject,
      ),
    );
  }
}
