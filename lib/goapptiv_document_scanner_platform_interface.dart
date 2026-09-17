import 'package:goapptiv_document_scanner/src/document_scanner_options.dart';
import 'package:goapptiv_document_scanner/src/document_scanning_result.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'goapptiv_document_scanner_method_channel.dart';

abstract class GoapptivDocumentScannerPlatform extends PlatformInterface {
  /// Constructs a GoapptivDocumentScannerPlatform.
  GoapptivDocumentScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static GoapptivDocumentScannerPlatform _instance =
      MethodChannelGoapptivDocumentScanner();

  /// The default instance of [GoapptivDocumentScannerPlatform] to use.
  ///
  /// Defaults to [MethodChannelGoapptivDocumentScanner].
  static GoapptivDocumentScannerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [GoapptivDocumentScannerPlatform] when
  /// they register themselves.
  static set instance(GoapptivDocumentScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPicture({bool letUserCropImage = true}) {
    throw UnimplementedError('getPicture() has not been implemented.');
  }

  Future<String?> getPictureFromGallery({bool letUserCropImage = true}) {
    throw UnimplementedError(
        'getPictureFromGallery() has not been implemented.');
  }

  Future<DocumentScanningResult> scanDocument(DocumentScannerOptions options) {
    throw UnimplementedError('scanDocument() has not been implemented.');
  }

  Future<void> closeScanner() {
    throw UnimplementedError('closeScanner() has not been implemented.');
  }
}
