import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:goapptiv_document_scanner/goapptiv_document_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  File? imageFile;

  final GoapptivDocumentScanner goapptivDocumentScanner =
      GoapptivDocumentScanner();

  StreamSubscription<DocumentScanningResult>? _recoveredScans;

  @override
  void initState() {
    super.initState();
    // Delivers a scan the user finished after Android killed the app.
    _recoveredScans =
        goapptivDocumentScanner.recoveredScanResults.listen((result) {
      if (result.images.isEmpty) return;
      setState(() => imageFile = File(result.images.first));
    });
  }

  @override
  void dispose() {
    _recoveredScans?.cancel();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          children: [
            if (imageFile != null)
              Expanded(child: Image(image: FileImage(imageFile!))),
            Expanded(
              child: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    if (Platform.isAndroid) {
                      final options = DocumentScannerOptions(
                        documentFormat: DocumentFormat.jpeg,
                        isGalleryImport: false,
                        mode: ScannerMode.baseMode,
                      );
                      try {
                        final result =
                            await goapptivDocumentScanner.scanDocument(options);
                        imageFile = File(result.images.first);
                        setState(() {});
                      } on Exception catch (e) {
                        print(e);
                      }
                    } else {
                      try {
                        final imagePath =
                            await GoapptivDocumentScanner.getPicture(
                          letUserCropImage: true,
                        );
                        if (imagePath != null) {
                          log(imagePath);
                          imageFile = File(imagePath);
                          setState(() {});
                        }
                      } on Exception catch (e) {
                        print(e);
                      }
                    }
                  },
                  child: const Text('Camera'),
                ),
              ),
            ),
            Flexible(
              child: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    if (Platform.isAndroid) {
                      final options = DocumentScannerOptions(
                        documentFormat: DocumentFormat.jpeg,
                        isGalleryImport: true,
                        mode: ScannerMode.baseMode,
                      );
                      try {
                        final result =
                            await goapptivDocumentScanner.scanDocument(options);
                        imageFile = File(result.images.first);
                        setState(() {});
                      } on Exception catch (e) {
                        print(e);
                      }
                    } else {
                      try {
                        final imagePath =
                            await GoapptivDocumentScanner.getPictureFromGallery(
                          letUserCropImage: true,
                        );
                        if (imagePath != null) {
                          log(imagePath);
                          imageFile = File(imagePath);
                          setState(() {});
                        }
                      } on Exception catch (e) {
                        print(e);
                      }
                    }
                  },
                  child: const Text('Gallery'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
