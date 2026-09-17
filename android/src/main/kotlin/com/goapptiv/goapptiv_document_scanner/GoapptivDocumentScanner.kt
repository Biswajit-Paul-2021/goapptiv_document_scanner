package com.goapptiv.goapptiv_document_scanner

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel


class GoapptivDocumentScanner : FlutterPlugin, ActivityAware {
    private lateinit var channel: MethodChannel
    val channelName: String = "goapptiv_document_scanner"

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, channelName)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        channel.setMethodCallHandler(DocumentScanner(binding))
    }

    override fun onDetachedFromActivityForConfigChanges() {
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        channel.setMethodCallHandler(DocumentScanner(binding))
    }

    override fun onDetachedFromActivity() {
    }
}
