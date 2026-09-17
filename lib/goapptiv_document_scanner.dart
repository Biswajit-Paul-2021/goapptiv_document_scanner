// You have generated a new plugin project without specifying the `--platforms`
// flag. A plugin project with no platform support was generated. To add a
// platform, run `flutter create -t plugin --platforms <platforms> .` under the
// same directory. You can also find a detailed instruction on how to add
// platforms in the `pubspec.yaml` at
// https://flutter.dev/docs/development/packages-and-plugins/developing-packages#plugin-platforms.

import 'package:goapptiv_document_scanner/src/document_scanner_options.dart';
import 'package:goapptiv_document_scanner/src/document_scanning_result.dart';

import 'goapptiv_document_scanner_platform_interface.dart';

export 'src/document_scanner_options.dart';
export 'src/document_scanning_result.dart';
export 'src/documet_scanning_result_pdf.dart';

class GoapptivDocumentScanner {
  static Future<String?> getPicture({bool letUserCropImage = true}) {
    return GoapptivDocumentScannerPlatform.instance
        .getPicture(letUserCropImage: letUserCropImage);
  }

  static Future<String?> getPictureFromGallery({bool letUserCropImage = true}) {
    return GoapptivDocumentScannerPlatform.instance
        .getPictureFromGallery(letUserCropImage: letUserCropImage);
  }

  Future<DocumentScanningResult> scanDocument(DocumentScannerOptions options) {
    return GoapptivDocumentScannerPlatform.instance.scanDocument(options);
  }

  Future<void> closeScanner() {
    return GoapptivDocumentScannerPlatform.instance.closeScanner();
  }
}
