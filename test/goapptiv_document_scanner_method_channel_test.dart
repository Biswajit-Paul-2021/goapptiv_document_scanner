import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goapptiv_document_scanner/goapptiv_document_scanner_method_channel.dart';

// These run on the test host, which takes the same path as iOS.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const scanner = MethodChannel('goapptiv_document_scanner');
  // permission_handler's channel: the plugin must not need it.
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MethodChannelGoapptivDocumentScanner platform;
  late List<String> scannerCalls;
  late List<String> permissionCalls;

  void nativeReturns(Object? Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(scanner, (call) async {
      scannerCalls.add(call.method);
      return reply(call);
    });
  }

  setUp(() {
    platform = MethodChannelGoapptivDocumentScanner();
    scannerCalls = [];
    permissionCalls = [];
    messenger.setMockMethodCallHandler(permissions, (call) async {
      permissionCalls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(scanner, null);
    messenger.setMockMethodCallHandler(permissions, null);
  });

  for (final method in ['getPicture', 'getPictureFromGallery']) {
    Future<String?> call() => method == 'getPicture'
        ? platform.getPicture()
        : platform.getPictureFromGallery();

    group(method, () {
      test('returns the saved file path without asking permission_handler', () async {
        nativeReturns((_) => 'file:///var/mobile/Library/scan.jpg');

        expect(await call(), '/var/mobile/Library/scan.jpg');
        expect(scannerCalls, [method]);
        expect(permissionCalls, isEmpty);
      });

      test('returns null when the user cancels', () async {
        nativeReturns((_) => null);

        expect(await call(), isNull);
      });

      test('passes on native errors such as refused camera access', () async {
        nativeReturns((_) => throw PlatformException(
            code: 'DocumentScanner', message: 'Camera access was denied'));

        await expectLater(
          call(),
          throwsA(isA<PlatformException>()
              .having((e) => e.message, 'message', 'Camera access was denied')),
        );
      });
    });
  }
}
