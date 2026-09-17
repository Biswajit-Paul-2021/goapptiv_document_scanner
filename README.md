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

iOS 13.0 or higher is needed to use the plugin. Change the minimum platform version to 13 (or higher) in your `ios/Podfile` file.

iOS 13.0 or higher is needed to use the plugin. If compiling for any version lower than 13.0 make sure to check the iOS version before using the plugin. Change the minimum platform version to 13 (or higher) in your `ios/Podfile` file, and inform/request access to the permissions acording with `permission_handler`

```podspec
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',

        ## dart: PermissionGroup.camera
         'PERMISSION_CAMERA=1',

        ## dart: PermissionGroup.photos
         'PERMISSION_PHOTOS=1',
      ]

    end
    # End of the permission_handler configuration
  end
end
```

## Fix build on xCode 15

Add this line to your Podfile in your project:

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
GoapptivDocumentScanner? goapptivDocumentScanner;

  @override
  void dispose() {
    goapptivDocumentScanner?.closeScanner();
    super.dispose();
  }

if (Platform.isAndroid) {
  final options = DocumentScannerOptions(
    documentFormat: DocumentFormat.pdf,
    isGalleryImport: true,
    mode: ScannerMode.baseMode,
  );
  try {
    goapptivDocumentScanner?.closeScanner();
    goapptivDocumentScanner = GoapptivDocumentScanner();
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
