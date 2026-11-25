import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:goapptiv_document_scanner/src/document_scanner_options.dart';
import 'package:goapptiv_document_scanner/src/document_scanning_result.dart';
import 'package:permission_handler/permission_handler.dart';

import 'goapptiv_document_scanner_platform_interface.dart';

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

  @override
  Future<String?> getPicture({bool letUserCropImage = true}) async {
    if (Platform.isAndroid) {
      throw Exception(
          "getPicture() is not supported on Android. Use scanDocument() instead.");
    }
    List<Permission> permissions = [Permission.camera];
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    if (statuses.containsValue(PermissionStatus.denied) ||
        statuses.containsValue(PermissionStatus.permanentlyDenied)) {
      throw Exception(permissionDenied);
    }
    final String? filePath = await methodChannel.invokeMethod("getPicture");
    return filePath?.split('file://')[1];
  }

  @override
  Future<String?> getPictureFromGallery({bool letUserCropImage = true}) async {
    if (Platform.isAndroid) {
      throw Exception(
          "getPictureFromGallery() is not supported on Android. Use scanDocument() instead.");
    }
    List<Permission> permissions = [];
    if (Platform.isIOS) {
      permissions.add(Permission.photos);
      Map<Permission, PermissionStatus> statuses = await permissions.request();
      if (statuses.containsValue(PermissionStatus.denied) ||
          statuses.containsValue(PermissionStatus.permanentlyDenied)) {
        throw Exception(permissionDenied);
      }
    }
    final String? filePath =
        await methodChannel.invokeMethod("getPictureFromGallery");
    return filePath?.split('file://')[1];
  }

  @override
  Future<DocumentScanningResult> scanDocument(
      DocumentScannerOptions options) async {
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
}
