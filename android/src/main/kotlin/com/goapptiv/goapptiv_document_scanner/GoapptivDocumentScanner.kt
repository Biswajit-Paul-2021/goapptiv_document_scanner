package com.goapptiv.goapptiv_document_scanner

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel


class GoapptivDocumentScanner : FlutterPlugin, ActivityAware {
    private lateinit var channel: MethodChannel
    // Created with the engine; the activity callbacks below only run while it is attached.
    private lateinit var scanner: DocumentScanner
    val channelName: String = "goapptiv_document_scanner"

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, channelName)
        scanner = DocumentScanner(flutterPluginBinding.applicationContext, channel)
        channel.setMethodCallHandler(scanner)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        scanner.attachToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        scanner.detachFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        scanner.attachToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        scanner.detachFromActivity()
    }
}
