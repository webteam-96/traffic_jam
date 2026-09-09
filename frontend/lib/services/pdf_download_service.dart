import 'dart:io';

import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

/// Saves a generated PDF where the user can find it again.
///
/// Android gets a real download: the file lands in the device's public
/// Downloads folder via MediaStore (see MainActivity.kt), which is what people
/// mean by "download" and what a file manager will show.
///
/// iOS has no shared Downloads folder — the system's own save mechanism is the
/// share sheet's "Save to Files", so that is what it uses there. Same intent,
/// different platform convention.
class PdfDownloadService {
  PdfDownloadService._();

  static const _channel = MethodChannel('trafficjam.life/downloads');

  /// Returns where it went, for showing the user. Throws on failure so the
  /// caller can say so rather than silently appearing to succeed.
  static Future<String> save(Uint8List bytes, String fileName) async {
    if (Platform.isAndroid) {
      final location = await _channel.invokeMethod<String>(
        'savePdfToDownloads',
        {'bytes': bytes, 'fileName': fileName},
      );
      return location ?? 'Downloads';
    }

    await Printing.sharePdf(bytes: bytes, filename: fileName);
    return 'Files';
  }
}
