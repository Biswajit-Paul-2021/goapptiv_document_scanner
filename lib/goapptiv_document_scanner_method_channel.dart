import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'goapptiv_document_scanner_platform_interface.dart';

const String permissionDenied = "PERMISSION_NOT_AVAILABLE";

/// An implementation of [GoapptivDocumentScannerPlatform] that uses method channels.
class MethodChannelGoapptivDocumentScanner
    extends GoapptivDocumentScannerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('goapptiv_document_scanner');

  @override
  Future<String?> getPicture({bool letUserCropImage = true}) async {
    List<Permission> permissions = [Permission.camera];
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    if (statuses.containsValue(PermissionStatus.denied)) {
      throw Exception(permissionDenied);
    }
    if (Platform.isAndroid) {
      final List<dynamic> pictures = await methodChannel.invokeMethod(
        'getPicture',
        {
          'letUserAdjustCrop': letUserCropImage,
        },
      );
      return pictures.isEmpty ? null : pictures.first;
    } else {
      final String? filePath = await methodChannel.invokeMethod("getPicture");
      return filePath?.split('file://')[1];
    }
  }

  @override
  Future<String?> getPictureFromGallery({bool letUserCropImage = true}) async {
    // No photo library permission is needed: on iOS the system photo picker
    // runs outside the app and hands over only the photo the user picks.
    if (Platform.isAndroid) {
      final List<dynamic> pictures = await methodChannel.invokeMethod(
        'getPictureFromGallery',
        {
          'letUserAdjustCrop': letUserCropImage,
        },
      );

      return pictures.isEmpty ? null : pictures.first;
    } else {
      final String? filePath =
          await methodChannel.invokeMethod("getPictureFromGallery");
      return filePath?.split('file://')[1];
    }
  }
}
