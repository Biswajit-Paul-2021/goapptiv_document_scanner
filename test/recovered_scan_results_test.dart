import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goapptiv_document_scanner/goapptiv_document_scanner.dart';
import 'package:goapptiv_document_scanner/goapptiv_document_scanner_method_channel.dart';

const MethodChannel channel = MethodChannel('goapptiv_document_scanner');

const Map<String, dynamic> storedScan = {
  'pdf': null,
  'images': ['/data/user/0/app/cache/scan_1.jpg'],
};

TestDefaultBinaryMessenger get messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

/// Mimics the native side: hands out the stored scan once, then nothing.
void mockNativeStore(Map<String, dynamic>? stored) {
  Map<String, dynamic>? pending = stored;
  messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
    if (call.method != 'vision#takeLostScanResult') return null;
    final result = pending;
    pending = null;
    return result;
  });
}

/// Mimics native code telling Dart that it has just stored a lost scan.
Future<void> notifyLostScanAvailable() async {
  await messenger.handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(
        const MethodCall('vision#lostScanResultAvailable')),
    (_) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelGoapptivDocumentScanner platform;

  setUp(() => platform = MethodChannelGoapptivDocumentScanner());
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('emits a scan that was stored before anyone listened', () async {
    mockNativeStore(storedScan);

    final result = await platform.recoveredScanResults.first;

    expect(result.images, storedScan['images']);
    expect(result.pdf, isNull);
  });

  test('emits a scan that is stored while listening', () async {
    mockNativeStore(null);
    final results = <DocumentScanningResult>[];
    final subscription = platform.recoveredScanResults.listen(results.add);
    await pumpEventQueue();
    expect(results, isEmpty);

    mockNativeStore(storedScan);
    await notifyLostScanAvailable();
    await pumpEventQueue();

    expect(results.single.images, storedScan['images']);
    await subscription.cancel();
  });

  test('emits a stored scan only once', () async {
    mockNativeStore(storedScan);
    final results = <DocumentScanningResult>[];
    final subscription = platform.recoveredScanResults.listen(results.add);
    await notifyLostScanAvailable();
    await pumpEventQueue();

    expect(results, hasLength(1));
    await subscription.cancel();
  });

  test('keeps the scan stored when nobody is listening', () async {
    var takeCalls = 0;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'vision#takeLostScanResult') takeCalls++;
      return null;
    });
    final subscription = platform.recoveredScanResults.listen((_) {});
    await pumpEventQueue();
    await subscription.cancel();
    takeCalls = 0;

    await notifyLostScanAvailable();
    await pumpEventQueue();

    expect(takeCalls, 0);
  });

  test('emits nothing on platforms that do not store lost scans', () async {
    // No mock handler, so the call fails with MissingPluginException, as on iOS.
    final results = <DocumentScanningResult>[];
    final errors = <Object>[];
    final subscription = platform.recoveredScanResults
        .listen(results.add, onError: errors.add);
    await pumpEventQueue();

    expect(results, isEmpty);
    expect(errors, isEmpty);
    await subscription.cancel();
  });
}
