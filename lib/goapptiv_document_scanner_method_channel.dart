import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:goapptiv_document_scanner/src/document_scanner_options.dart';
import 'package:goapptiv_document_scanner/src/document_scanning_result.dart';

import 'goapptiv_document_scanner_platform_interface.dart';

@Deprecated('No longer thrown. On iOS, refused camera access is reported as a '
    'PlatformException with the message "Camera access was denied".')
const String permissionDenied = "PERMISSION_NOT_AVAILABLE";

/// An implementation of [GoapptivDocumentScannerPlatform] that uses method channels.
class MethodChannelGoapptivDocumentScanner
    extends GoapptivDocumentScannerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('goapptiv_document_scanner');

  /// The id of the scanner currently held by the native side, if any.
  ///
  /// The native side caches one scanner per id, together with the options it
  /// was created with, so reusing an id silently reuses the earlier options.
  /// This class is reached through [GoapptivDocumentScannerPlatform.instance],
  /// a single object shared by every caller in the app, so an id held per
  /// instance would be shared by the host app and any package that also
  /// depends on this plugin. Each scan therefore gets a fresh id.
  String? _activeScannerId;

  static int _scannerIdCounter = 0;

  StreamController<DocumentScanningResult>? _recoveredScanResults;

  @override
  Future<String?> getPicture({bool letUserCropImage = true}) async {
    if (Platform.isAndroid) {
      throw Exception(
          "getPicture() is not supported on Android. Use scanDocument() instead.");
    }
    // The plugin's iOS code asks for camera access itself, and reports a
    // refusal as a PlatformException ("Camera access was denied").
    final String? filePath = await methodChannel.invokeMethod("getPicture");
    return filePath?.split('file://')[1];
  }

  @override
  Future<String?> getPictureFromGallery({bool letUserCropImage = true}) async {
    if (Platform.isAndroid) {
      throw Exception(
          "getPictureFromGallery() is not supported on Android. Use scanDocument() instead.");
    }
    // No photo library permission is needed: the system photo picker runs
    // outside the app and hands over only the photo the user picks.
    final String? filePath =
        await methodChannel.invokeMethod("getPictureFromGallery");
    return filePath?.split('file://')[1];
  }

  @override
  Future<DocumentScanningResult> scanDocument(DocumentScannerOptions options,
      {String? tag}) async {
    // Release the scanner kept for the previous scan so its options cannot
    // leak into this one.
    await closeScanner();

    final String scannerId =
        '${DateTime.now().microsecondsSinceEpoch}-${_scannerIdCounter++}';
    _activeScannerId = scannerId;

    final dynamic results = await methodChannel
        .invokeMapMethod<dynamic, dynamic>(
            'vision#startDocumentScanner', <String, dynamic>{
      'options': options.toJson(),
      'id': scannerId,
      'tag': tag,
    });
    return DocumentScanningResult.fromJson(results);
  }

  @override
  Future<void> closeScanner() async {
    final String? scannerId = _activeScannerId;
    if (scannerId == null) return;
    _activeScannerId = null;
    await methodChannel
        .invokeMethod<void>('vision#closeDocumentScanner', {'id': scannerId});
  }

  @override
  Stream<DocumentScanningResult> get recoveredScanResults {
    return (_recoveredScanResults ??=
            StreamController<DocumentScanningResult>.broadcast(
      onListen: () {
        // Registered on first listen rather than in the constructor, because
        // the platform instance can be created before the Flutter binding.
        methodChannel.setMethodCallHandler(_handleNativeCall);
        // Collect a scan that was stored before anyone was listening.
        _deliverRecoveredScanResult();
      },
    ))
        .stream;
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'vision#lostScanResultAvailable':
        await _deliverRecoveredScanResult();
        return null;
      default:
        throw MissingPluginException();
    }
  }

  /// Asks the native side for its stored scan, if any, and emits it.
  ///
  /// Native code hands a stored scan out only once, so the listen-time check
  /// and the native notification cannot both emit the same scan.
  Future<void> _deliverRecoveredScanResult() async {
    final controller = _recoveredScanResults;
    // Without a listener the scan stays stored for the next listener.
    if (controller == null || !controller.hasListener) return;
    try {
      final results = await methodChannel
          .invokeMapMethod<dynamic, dynamic>('vision#takeLostScanResult');
      if (results != null) {
        controller.add(DocumentScanningResult.fromJson(results));
      }
    } on MissingPluginException {
      // Platforms other than Android do not store lost scans.
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    }
  }
}
