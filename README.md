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

The plugin asks for camera access itself the first time the camera opens, so it only needs the camera usage description in your `Info.plist` (see below). If the user refuses, `getPicture()` throws a `PlatformException` with the message "Camera access was denied"; the user can then allow it in the Settings app.

Picking from the gallery needs no photo library permission: the system photo picker runs outside your app and hands over only the photo the user picks.

The plugin no longer depends on `permission_handler`. If you added `PERMISSION_CAMERA=1`, `PERMISSION_PHOTOS=1` or `NSPhotoLibraryUsageDescription` only for this plugin, you can remove them.

The plugin supports both Swift Package Manager and CocoaPods; Flutter picks whichever your app uses. It includes a privacy manifest declaring its use of `UserDefaults` (to remember the camera's Auto/Manual choice).

Xcode 27 only builds for iOS 15 and later, and reports an error for any pod that declares a lower minimum. Some Flutter versions, including 3.41, don't fix this up for every pod, such as the resource bundles of other plugins' pods. If you see "The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 9.0, but the range of supported deployment target versions is 15.0 to ...", extend the `post_install` block in your `ios/Podfile`:

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
- The editor starts with the corners the plugin found (`VNDetectDocumentSegmentationRequest`), or a frame just inside the photo's edges if it found none. The user drags the corners, or the bar in the middle of an edge to move that whole edge (up and down for the top and bottom, sideways for the sides). While dragging, a magnified view shows the point being moved. The rotate button turns the photo a quarter turn at a time, and "Done" returns the document cropped, straightened and turned.
- If the user cancels, both return `null`.
- The camera doesn't run on the iOS simulator; use a real device.

Add below permission to the `ios/Runner/Info.plist`:

- one with the key `Privacy - Camera Usage Description` and a usage description.

Or in text format add the key:

```xml
<key>NSCameraUsageDescription</key>
<string>Can I use the camera please?</string>
```

#### Upgrading from a version that used WeScan

WeScan has been removed. Delete this line from your app's `ios/Podfile`, then run `pod install`:

```
pod 'WeScan', :path => '.symlinks/plugins/goapptiv_document_scanner/ios/WeScan-3.0.0'
```

### Android

The plugin's Android code is written in Java, so it needs no particular Kotlin version in your app and works with Android Gradle Plugin 8 and 9.

Change the minimum Android SDK version to 24 (or higher) in your `android/app/build.gradle` file.

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

### Recovering scans after Android kills the app

On low-memory devices Android may kill the app while the scanner is open. When
the user finishes scanning, the app restarts, and the `scanDocument()` call
that was waiting can no longer complete. The plugin keeps the finished scan and
delivers it through `recoveredScanResults` instead. Listen to it once the app
has started; a scan stored before you listen is delivered as soon as you do.

```dart
late final StreamSubscription<DocumentScanningResult> recoveredScans;

@override
void initState() {
  super.initState();
  recoveredScans = goapptivDocumentScanner.recoveredScanResults.listen((result) {
    // Same result as scanDocument() would have returned.
    log(result.toString());
  });
}

@override
void dispose() {
  recoveredScans.cancel();
  super.dispose();
}
```

A recovered scan has lost the context it was started from: the screen, bottom
sheet or list item that asked for it. Pass a `tag` when scanning to know what it
was for. The tag is saved with the scan and comes back as `result.tag`.

```dart
await goapptivDocumentScanner.scanDocument(options, tag: 'customer-proof:$customerId');

goapptivDocumentScanner.recoveredScanResults.listen((result) {
  final tag = result.tag;
  if (tag != null && tag.startsWith('customer-proof:')) {
    uploadProof(tag.substring('customer-proof:'.length), result.images.first);
  }
});
```

Listen in one place that is always on screen after the app restarts, such as
the screen hosting the bottom navigation bar. Don't listen inside list items or
bottom sheets: they may not be rebuilt, and each scan is delivered only to the
listeners that exist when it arrives.

To also return the user to the screen they were on, enable Flutter state
restoration, e.g. `MaterialApp.router(restorationScopeId: 'app', ...)`.

## Authors

- [@BiswajitP](https://github.com/Biswajit-Paul-2021)
