import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StudentRegistrationPage extends StatefulWidget {
  @override
  _StudentRegistrationPageState createState() => _StudentRegistrationPageState();
}

class _StudentRegistrationPageState extends State<StudentRegistrationPage> {
  static const platform = MethodChannel('com.example.fingerprint_mis7/usb_fingerprint');

  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _programController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _status = 'Idle';
  Uint8List? _fingerprintTemplate;
  StreamSubscription? _methodCallSubscription;

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
        // We do not display image here, but could be extended if needed
        break;
      case 'onTemplate':
        {
          final Uint8List templateData = call.arguments;
          setState(() {
            _fingerprintTemplate = templateData;
            _status = 'Fingerprint template captured';
          });
        }
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
        _fingerprintTemplate = null;
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

  Future<void> _saveStudentData() async {
    final studentId = _studentIdController.text.trim();
    final firstName = _firstNameController.text.trim();
    final middleName = _middleNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final department = _departmentController.text.trim();
    final program = _programController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (studentId.isEmpty) {
      setState(() {
        _status = 'Please enter student ID';
      });
      return;
    }
    if (firstName.isEmpty) {
      setState(() {
        _status = 'Please enter first name';
      });
      return;
    }
    if (lastName.isEmpty) {
      setState(() {
        _status = 'Please enter last name';
      });
      return;
    }
    if (department.isEmpty) {
      setState(() {
        _status = 'Please enter department';
      });
      return;
    }
    if (program.isEmpty) {
      setState(() {
        _status = 'Please enter program';
      });
      return;
    }
    if (email.isEmpty) {
      setState(() {
        _status = 'Please enter email';
      });
      return;
    }
    if (password.isEmpty) {
      setState(() {
        _status = 'Please enter password';
      });
      return;
    }
    if (_fingerprintTemplate == null) {
      setState(() {
        _status = 'No fingerprint template captured';
      });
      return;
    }

    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCredential.user?.uid;

      final base64Template = base64Encode(_fingerprintTemplate!);
      final docRef = FirebaseFirestore.instance.collection('students').doc(studentId);
      print('Saving student data for $studentId');
      await docRef.set({
        'studentId': studentId,
        'firstName': firstName,
        'middleName': middleName.isEmpty ? null : middleName,
        'lastName': lastName,
        'department': department,
        'program': program,
        'email': email,
        'uid': uid,
        'fingerprintTemplate': base64Template,
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() {
        _status = 'Student data saved successfully';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _status = 'Firebase Auth error: ${e.message}';
      });
    } catch (e, stacktrace) {
      print('Error saving student data: $e');
      print(stacktrace);
      setState(() {
        _status = 'Failed to save student data: $e';
      });
    }
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _departmentController.dispose();
    _programController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Registration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _studentIdController,
                decoration: InputDecoration(
                  labelText: 'Student ID',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _middleNameController,
                decoration: InputDecoration(
                  labelText: 'Middle Name (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _departmentController,
                decoration: InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _programController,
                decoration: InputDecoration(
                  labelText: 'Program',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 20),
              Text('Status: $_status'),
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
                    onPressed: _saveStudentData,
                    child: Text('Save Student Data'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

