import 'dart:html' as html;
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

class ImageExport {
  static Future<bool> requestGalleryAccess() async => true;

  static Future<void> savePng(Uint8List bytes, String filename) async {
    final blob = html.Blob([bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
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
