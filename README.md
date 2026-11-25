# GoApptiv Document Scanner

A Document scanner plugin for scanning of invoice and KYC documents with edge detection and cropping facility.

## Installation

Get the package

```yaml
goapptiv_document_scanner:
  git:
    url: https://github.com/GoApptiv/goapptiv_document_scanner.git
    ref: main
```

## Usage/Examples

### iOS

iOS 15.0 or higher is needed to use the plugin. Change the minimum platform version to 15 (or higher) in your `ios/Podfile` file.

The camera needs camera permission, which the plugin requests through `permission_handler`. Enable it in the `post_install` block of your `ios/Podfile`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        ## dart: PermissionGroup.camera
        'PERMISSION_CAMERA=1',
      ]
    end
  end
end
```

Picking from the gallery needs no photo library permission: the system photo picker runs outside your app and hands over only the photo the user picks. If you added `PERMISSION_PHOTOS=1` or `NSPhotoLibraryUsageDescription` only for this plugin, you can remove them.

Xcode 27 only builds for iOS 15 and later, and reports an error for any pod that declares a lower minimum. Some Flutter versions, including 3.41, don't fix this up for every pod, such as resource bundles, such as `permission_handler_apple`'s. If you see "The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 9.0, but the range of supported deployment target versions is 15.0 to ...", extend the `post_install` block in your `ios/Podfile`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 15.0
        config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
      end
    end
  end
end
```

The plugin uses Apple's own frameworks, so no extra pods are needed:

- `getPicture()` opens a camera that outlines the document live as the user aims. In "Auto" mode (the default; tap it to switch to "Manual") the photo is taken by itself once the document has held still for about a second, and the outline turns green just before. The shutter button works in both modes. After the photo is taken, a corner editor opens; "Retake" goes back to the camera.
- `getPictureFromGallery()` opens the photo picker, then the same corner editor for the picked photo.
- The editor starts with the corners the plugin found (`VNDetectDocumentSegmentationRequest`), or a frame just inside the photo's edges if it found none. The user drags the corners, can turn the photo a quarter turn at a time with the rotate button, and "Done" returns the document cropped, straightened and turned.
- If the user cancels, both return `null`.
- The camera doesn't run on the iOS simulator; use a real device.

## Upgrading from a version that used WeScan

WeScan has been removed. Delete this line from your app's `ios/Podfile`, then run `pod install`:

```
pod 'WeScan', :path => '.symlinks/plugins/goapptiv_document_scanner/ios/WeScan-3.0.0'
```

=> like this below:

```podspec
target 'Runner' do
  use_frameworks!
  use_modular_headers!
  pod 'WeScan', :path => '.symlinks/plugins/goapptiv_document_scanner/ios/WeScan-3.0.0'
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end
```

Add below permission to the `ios/Runner/Info.plist`:

- one with the key `Privacy - Camera Usage Description` and a usage description.

Or in text format add the key:

```xml
<key>NSCameraUsageDescription</key>
<string>Can I use the camera please?</string>
```

### Android

The plugin code is written in kotlin 2.1.20 so the same has to be set to the android project of yours for compilation.
Change the kotlin_version to 2.1.20 in your `android/build.gradle` file.

```
ext.kotlin_version = '2.3.20'
```

Change the minimum Android SDK version to 21 (or higher) in your `android/app/build.gradle` file.

```
minSdkVersion 24
```

### Add dependency：

Please check the latest version before installation.

```yaml
dependencies:
  flutter:
    sdk: flutter
  goapptiv_document_scanner:
    git:
      url: https://github.com/GoApptiv/goapptiv_document_scanner.git
      ref: main
```

### Add the following imports to your Dart code:

```dart
import 'package:goapptiv_document_scanner/goapptiv_document_scanner.dart';
```

```dart

// Only require for Android to close the scanner for releasing the resources
final GoapptivDocumentScanner goapptivDocumentScanner =
      GoapptivDocumentScanner();

if (Platform.isAndroid) {
  final options = DocumentScannerOptions(
    documentFormat: DocumentFormat.jpeg,
    isGalleryImport: true,
    mode: ScannerMode.baseMode,
  );
  try {
    final result = await goapptivDocumentScanner?.scanDocument(options);
    log(result.toString());
  } on Exception catch (e) {
      print(e);
  }
} else {
  try {
    final imagePath =
    await GoapptivDocumentScanner.getPicture();
    if (imagePath != null) {
      log(imagePath);
      imageFile = File(imagePath);
      setState(() {});
    }
  } on Exception catch (e) {
    print(e);
  }
}

```

## Authors

- [@BiswajitP](https://github.com/Biswajit-Paul-2021)
