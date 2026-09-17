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

  final id = DateTime.now().microsecondsSinceEpoch.toString();

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
    final dynamic results = await methodChannel
        .invokeMapMethod<dynamic, dynamic>(
            'vision#startDocumentScanner', <String, dynamic>{
      'options': options.toJson(),
      'id': id,
    });
    return DocumentScanningResult.fromJson(results);
  }

  @override
  Future<void> closeScanner() {
    debugPrint("current ID: $id");
    return methodChannel
        .invokeMethod<void>('vision#closeDocumentScanner', {'id': id});
  }
}
