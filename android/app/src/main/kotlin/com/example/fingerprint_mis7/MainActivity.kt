package com.example.fingerprint_mis7

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.fingerprint_mis7/usb_fingerprint"

    private var usbFingerprintReader: UsbFingerprintReader? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val messenger = flutterEngine?.dartExecutor?.binaryMessenger
            ?: throw IllegalStateException("BinaryMessenger is null")

        usbFingerprintReader = UsbFingerprintReader(this, MethodChannel(messenger, CHANNEL))

        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openDevice" -> {
                    val success = usbFingerprintReader?.openDevice() ?: false
                    result.success(success)
                }
                "closeDevice" -> {
                    usbFingerprintReader?.closeDevice()
                    result.success(null)
                }
                "enrollTemplate" -> {
                    usbFingerprintReader?.enrollTemplate()
                    result.success(null)
                }
                "generateTemplate" -> {
                    usbFingerprintReader?.generateTemplate()
                    result.success(null)
                }
                "pauseUnregister" -> {
                    usbFingerprintReader?.pauseUnregister()
                    result.success(null)
                }
                "resumeRegister" -> {
                    usbFingerprintReader?.resumeRegister()
                    result.success(null)
                }
                "matchTemplates" -> {
                    val args = call.arguments as Map<String, Any>
                    val template1 = args["template1"] as ByteArray
                    val template2 = args["template2"] as ByteArray
                    val score = usbFingerprintReader?.matchTemplates(template1, template2) ?: -1
                    result.success(score)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
