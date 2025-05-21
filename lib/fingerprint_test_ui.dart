import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'screens/auth/register/student_registration_page.dart';
import 'screens/admin/student_verification_page.dart';
import 'screens/instructor/student_attendance_page.dart';

class FingerprintTestUI extends StatefulWidget {
  @override
  _FingerprintTestUIState createState() => _FingerprintTestUIState();
}

class _FingerprintTestUIState extends State<FingerprintTestUI> {
  static const platform = MethodChannel('com.example.fingerprint_mis7/usb_fingerprint');

  String _status = 'Idle';
  Uint8List? _fingerprintImage;

  @override
  void initState() {
    super.initState();
    platform.setMethodCallHandler(_handleNativeCalls);
  }

  Future<void> _handleNativeCalls(MethodCall call) async {
    switch (call.method) {
      case 'onStatus':
        setState(() {
          _status = call.arguments as String;
        });
        break;
      case 'onImage':
        setState(() {
          _fingerprintImage = call.arguments as Uint8List;
        });
        break;
      default:
        break;
    }
  }

  Future<void> _openDevice() async {
    try {
      final bool result = await platform.invokeMethod('openDevice');
      setState(() {
        _status = result ? 'Device opened' : 'Failed to open device';
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = "Failed to open device: '${e.message}'.";
      });
    }
  }

  Future<void> _closeDevice() async {
    try {
      await platform.invokeMethod('closeDevice');
      setState(() {
        _status = 'Device closed';
        _fingerprintImage = null;
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = "Failed to close device: '${e.message}'.";
      });
    }
  }

  Future<void> _enrollTemplate() async {
    try {
      await platform.invokeMethod('enrollTemplate');
      setState(() {
        _status = 'Enroll started';
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = "Failed to enroll: '${e.message}'.";
      });
    }
  }

  Future<void> _generateTemplate() async {
    try {
      await platform.invokeMethod('generateTemplate');
      setState(() {
        _status = 'Generate template started';
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = "Failed to generate template: '${e.message}'.";
      });
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ requires READ_MEDIA_IMAGES permission
        final status = await Permission.photos.request();
        return status.isGranted;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    } else {
      // For other platforms, assume permission granted
      return true;
    }
  }

  Future<void> _saveImage() async {
    if (_fingerprintImage == null) {
      setState(() {
        _status = 'No image to save';
      });
      return;
    }

    final granted = await _requestStoragePermission();
    if (!granted) {
      setState(() {
        _status = 'Storage permission denied';
      });
      return;
    }

    try {
      final directories = await getExternalStorageDirectories(type: StorageDirectory.pictures);
      final picturesDir = directories?.first;
      if (picturesDir == null) {
        setState(() {
          _status = 'Cannot access Pictures directory';
        });
        return;
      }
      final fpsDir = Directory('${picturesDir.path}/FPS');
      if (!await fpsDir.exists()) {
        await fpsDir.create(recursive: true);
      }
      final file = File('${fpsDir.path}/fingerprint_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(_fingerprintImage!);
      setState(() {
        _status = 'Image saved successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to save image: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fingerprint Reader Test UI'),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add),
            tooltip: 'Student Registration',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StudentRegistrationPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.search),
            tooltip: 'Student Verification',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StudentVerificationPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.check_circle_outline),
            tooltip: 'Student Attendance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StudentAttendancePage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Status: $_status'),
            SizedBox(height: 20),
            _fingerprintImage != null
                ? Image.memory(_fingerprintImage!)
                : Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey[300],
                    child: Center(child: Text('Fingerprint Image')),
                  ),
            SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: [
                ElevatedButton(
                  onPressed: _openDevice,
                  child: Text('Open Device'),
                ),
                ElevatedButton(
                  onPressed: _closeDevice,
                  child: Text('Close Device'),
                ),
                ElevatedButton(
                  onPressed: _enrollTemplate,
                  child: Text('Enroll Template'),
                ),
                ElevatedButton(
                  onPressed: _generateTemplate,
                  child: Text('Generate Template'),
                ),
                ElevatedButton(
                  onPressed: _saveImage,
                  child: Text('Save Image'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

