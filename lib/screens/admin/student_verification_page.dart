import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StudentVerificationPage extends StatefulWidget {
  @override
  _StudentVerificationPageState createState() => _StudentVerificationPageState();
}

class _StudentVerificationPageState extends State<StudentVerificationPage> {
  static const platform = MethodChannel('com.example.fingerprint_mis7/usb_fingerprint');

  String _status = 'Idle';
  Uint8List? _scannedTemplate;
  Map<String, String> _students = {}; // studentId -> base64 fingerprint template
  String? _matchedStudentId;
  Map<String, dynamic>? _matchedStudentData;

  @override
  void initState() {
    super.initState();
    platform.setMethodCallHandler(_handleNativeCalls);
    _loadRegisteredStudents();
  }

  Future<void> _handleNativeCalls(MethodCall call) async {
    switch (call.method) {
      case 'onStatus':
        setState(() {
          _status = call.arguments as String;
        });
        break;
      case 'onImage':
        // Not used here
        break;
      case 'onTemplate':
        {
          final Uint8List templateData = call.arguments;
          _matchFingerprint(templateData);
        }
        break;
      default:
        break;
    }
  }

  Future<void> _loadRegisteredStudents() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('students').get();
      final Map<String, String> studentsMap = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('studentId') && data.containsKey('fingerprintTemplate')) {
          studentsMap[data['studentId']] = data['fingerprintTemplate'];
        }
      }
      setState(() {
        _students = studentsMap;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load registered students: $e';
      });
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
        _scannedTemplate = null;
        _matchedStudentId = null;
        _matchedStudentData = null;
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = "Failed to close device: '${e.message}'.";
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

  void _matchFingerprint(Uint8List scannedTemplate) async {
    int bestScore = -1;
    String? bestMatchId;

    for (var entry in _students.entries) {
      final studentId = entry.key;
      final storedBase64 = entry.value;
      final storedTemplate = base64Decode(storedBase64);

      try {
        final int score = await platform.invokeMethod('matchTemplates', {
          'template1': scannedTemplate,
          'template2': storedTemplate,
        });
        if (score > bestScore) {
          bestScore = score;
          bestMatchId = studentId;
        }
      } catch (e) {
        // Handle error if needed
      }
    }

    if (bestScore > 40 && bestMatchId != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('students').doc(bestMatchId).get();
        setState(() {
          _matchedStudentId = bestMatchId;
          _matchedStudentData = doc.data();
          _status = 'Match found: $bestMatchId (score: $bestScore)';
        });
      } catch (e) {
        setState(() {
          _status = 'Failed to load student data: $e';
          _matchedStudentId = null;
          _matchedStudentData = null;
        });
      }
    } else {
      setState(() {
        _matchedStudentId = null;
        _matchedStudentData = null;
        _status = 'No match found';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Verification'),
        backgroundColor: Colors.teal.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Status: $_status', style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: [
                ElevatedButton(
                  onPressed: _openDevice,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade600),
                  child: Text('Open Device'),
                ),
                ElevatedButton(
                  onPressed: _closeDevice,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade600),
                  child: Text('Close Device'),
                ),
                ElevatedButton(
                  onPressed: _generateTemplate,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade600),
                  child: Text('Scan Fingerprint'),
                ),
              ],
            ),
            SizedBox(height: 20),
            _matchedStudentData != null
                ? Card(
                    color: Colors.teal.shade50,
                    margin: EdgeInsets.symmetric(vertical: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Student ID: ${_matchedStudentData!['studentId'] ?? ''}', style: TextStyle(fontSize: 16, color: Colors.teal.shade900, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text(
                            'Name: ${[_matchedStudentData!['firstName'], _matchedStudentData!['middleName'], _matchedStudentData!['lastName']].where((s) => s != null && s.isNotEmpty).join(' ')}',
                            style: TextStyle(fontSize: 16, color: Colors.teal.shade800),
                          ),
                          SizedBox(height: 4),
                          Text('Email: ${_matchedStudentData!['email'] ?? ''}', style: TextStyle(fontSize: 16, color: Colors.teal.shade800)),
                          SizedBox(height: 4),
                          Text('Department: ${_matchedStudentData!['department'] ?? ''}', style: TextStyle(fontSize: 16, color: Colors.teal.shade800)),
                          SizedBox(height: 4),
                          Text('Program: ${_matchedStudentData!['program'] ?? ''}', style: TextStyle(fontSize: 16, color: Colors.teal.shade800)),
                        ],
                      ),
                    ),
                  )
                : Text('No student matched', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
