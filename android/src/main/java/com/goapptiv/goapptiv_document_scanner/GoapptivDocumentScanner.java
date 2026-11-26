package com.goapptiv.goapptiv_document_scanner;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodChannel;

/**
 * Plugin entry point. Written in Java, like the rest of the plugin's Android code,
 * so the plugin needs no Kotlin setup in the apps that use it.
 */
public class GoapptivDocumentScanner implements FlutterPlugin, ActivityAware {
    private static final String CHANNEL_NAME = "goapptiv_document_scanner";

    private MethodChannel channel;
    // Created with the engine; the activity callbacks below only run while it is attached.
    private DocumentScanner scanner;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), CHANNEL_NAME);
        scanner = new DocumentScanner(flutterPluginBinding.getApplicationContext(), channel);
        channel.setMethodCallHandler(scanner);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        scanner.attachToActivity(binding);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        scanner.detachFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        scanner.attachToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        scanner.detachFromActivity();
    }
}
