import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExamVerificationPage extends StatefulWidget {
  @override
  _ExamVerificationPageState createState() => _ExamVerificationPageState();
}

class _ExamVerificationPageState extends State<ExamVerificationPage> {
  static const platform = MethodChannel('com.example.fingerprint_mis7/usb_fingerprint');

  String _status = 'Idle';
  Map<String, String> _students = {}; // studentId -> base64 fingerprint template
  String? _matchedStudentId;
  Map<String, dynamic>? _matchedStudentData;
  bool? _isEnrolled;
  bool? _examScheduled;

  String? _selectedCourseId;
  String _selectedExamType = 'Exam'; // default to Exam
  List<Map<String, dynamic>> _coursesWithExam = [];

  @override
  void initState() {
    super.initState();
    platform.setMethodCallHandler(_handleNativeCalls);
    _loadRegisteredStudents();
    _fetchCoursesWithExam();
  }

  Future<void> _handleNativeCalls(MethodCall call) async {
    switch (call.method) {
      case 'onStatus':
        setState(() {
          _status = call.arguments as String;
        });
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

  Future<void> _fetchCoursesWithExam() async {
    try {
      final user = await FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _status = 'Failed to get current user ID';
        });
        return;
      }
      final userId = user.uid;

      final coursesSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where('assignedInvigilatorId', isEqualTo: userId)
          .get();

      final List<Map<String, dynamic>> courses = [];
      for (var doc in coursesSnapshot.docs) {
        final data = doc.data();
        courses.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Course',
          'code': data['code'] ?? '',
          'examDate': (data['examDate'] as Timestamp?)?.toDate(),
          'catDate': (data['catDate'] as Timestamp?)?.toDate(),
        });
      }
      setState(() {
        _coursesWithExam = courses;
        if (courses.isNotEmpty) {
          _selectedCourseId = courses[0]['id'];
        } else {
          _selectedCourseId = null;
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to fetch courses with exams: $e';
      });
    }
  }

  Future<void> _checkExamScheduled() async {
    if (_selectedCourseId == null) {
      setState(() {
        _examScheduled = false;
        _status = 'Please select a course';
      });
      return;
    }
    try {
      final courseDoc = await FirebaseFirestore.instance.collection('courses').doc(_selectedCourseId).get();
      if (!courseDoc.exists) {
        setState(() {
          _examScheduled = false;
          _status = 'Course not found';
        });
        return;
      }
      final data = courseDoc.data()!;
      DateTime? examDate;
      if (_selectedExamType == 'Exam') {
        examDate = (data['examDate'] as Timestamp?)?.toDate();
      } else if (_selectedExamType == 'CAT') {
        examDate = (data['catDate'] as Timestamp?)?.toDate();
      }
      if (examDate == null) {
        setState(() {
          _examScheduled = false;
          _status = '$_selectedExamType date not set for this course';
        });
        return;
      }
      final now = DateTime.now();
      final isToday = examDate.year == now.year && examDate.month == now.month && examDate.day == now.day;
      setState(() {
        _examScheduled = isToday;
        _status = isToday ? 'Ready to scan fingerprint' : '$_selectedExamType is not scheduled for today';
      });
    } catch (e) {
      setState(() {
        _examScheduled = false;
        _status = 'Failed to check exam schedule: $e';
      });
    }
  }

  void _markPresentForExam() async {
    if (_matchedStudentId == null || !_isEnrolled! || _examScheduled != true) {
      setState(() {
        _status = 'Cannot mark present: student not matched, not enrolled, or exam not scheduled';
      });
      return;
    }
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('exam_attendance')
          .where('studentId', isEqualTo: _matchedStudentId)
          .where('courseId', isEqualTo: _selectedCourseId)
          .where('examType', isEqualTo: _selectedExamType)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .get();

      if (attendanceQuery.docs.isNotEmpty) {
        setState(() {
          _status = 'Attendance already marked for this student for today\'s $_selectedExamType';
        });
        return;
      }

      // Find course name from _coursesWithExam list
      String courseName = '';
      for (var course in _coursesWithExam) {
        if (course['id'] == _selectedCourseId) {
          courseName = course['name'] ?? '';
          break;
        }
      }

      await FirebaseFirestore.instance.collection('exam_attendance').add({
        'studentId': _matchedStudentId,
        'courseId': _selectedCourseId,
        'courseName': courseName,
        'examType': _selectedExamType,
        'status': 'Present',
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _status = 'Marked present for student $_matchedStudentId for today\'s $_selectedExamType';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to mark present: $e';
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
        final studentData = doc.data();
        if (studentData == null) {
          setState(() {
            _status = 'Student data not found';
            _matchedStudentId = null;
            _matchedStudentData = null;
            _isEnrolled = null;
          });
          return;
        }
        final studentIdFromData = studentData['studentId'] ?? bestMatchId;
        final enrolled = await _checkEnrollment(studentIdFromData);
        setState(() {
          _matchedStudentId = studentIdFromData;
          _matchedStudentData = studentData;
          _isEnrolled = enrolled;
          _status = 'Match found: $studentIdFromData (score: $bestScore)';
        });
      } catch (e) {
        setState(() {
          _status = 'Failed to load student data: $e';
          _matchedStudentId = null;
          _matchedStudentData = null;
          _isEnrolled = null;
        });
      }
    } else {
      setState(() {
        _matchedStudentId = null;
        _matchedStudentData = null;
        _isEnrolled = null;
        _status = 'No match found';
      });
    }
  }

  Future<bool> _checkEnrollment(String studentId) async {
    print('Checking enrollment for studentId: $studentId, courseId: $_selectedCourseId');
    final querySnapshot = await FirebaseFirestore.instance
        .collection('joined_courses')
        .where('courseId', isEqualTo: _selectedCourseId)
        .where('studentId', isEqualTo: studentId)
        .get();
    print('Enrollment query returned ${querySnapshot.docs.length} documents');
    return querySnapshot.docs.isNotEmpty;
  }

  Future<void> _openDevice() async {
    try {
      final bool result = await platform.invokeMethod('openDevice');
      setState(() {
        _status = result ? 'Device opened' : 'Failed to open device';
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = "Failed to open device: '${e.message}'";
      });
    }
  }

  Future<void> _closeDevice() async {
    try {
      await platform.invokeMethod('closeDevice');
      setState(() {
        _status = 'Device closed';
        _matchedStudentId = null;
        _matchedStudentData = null;
        _isEnrolled = null;
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = "Failed to close device: '${e.message}'";
      });
    }
  }

  Future<void> _generateTemplate() async {
    try {
      await platform.invokeMethod('generateTemplate');
      setState(() {
        _status = 'Scan fingerprint to verify student';
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = "Failed to generate template: '${e.message}'";
      });
    }
  }

  Widget _buildStudentInfo() {
    if (_matchedStudentData == null) {
      return Text('No student matched', style: TextStyle(fontSize: 16));
    }
    if (_isEnrolled == false) {
      return Text('Student is not enrolled in this course', style: TextStyle(fontSize: 16, color: Colors.red));
    }
    final data = _matchedStudentData!;
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student ID: ${data['studentId'] ?? ''}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Name: ${[data['firstName'], data['middleName'], data['lastName']].where((s) => s != null && s.isNotEmpty).join(' ')}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text('Email: ${data['email'] ?? ''}', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Department: ${data['department'] ?? ''}', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Program: ${data['program'] ?? ''}', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exam Verification'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedCourseId,
                      decoration: InputDecoration(
                        labelText: 'Select Course',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: _coursesWithExam.map((course) {
                        return DropdownMenuItem<String>(
                          value: course['id'],
                          child: Text('${course['name']} (${course['code']})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCourseId = value;
                          _checkExamScheduled();
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedExamType,
                      decoration: InputDecoration(
                        labelText: 'Select Exam Type',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Exam', 'CAT'].map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedExamType = value ?? 'Exam';
                          _checkExamScheduled();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Status: $_status', style: TextStyle(fontSize: 16)),
                    SizedBox(height: 16),
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
                          onPressed: _generateTemplate,
                          child: Text('Scan Fingerprint'),
                        ),
                        if (_matchedStudentId != null && _isEnrolled == true && _examScheduled == true)
                          ElevatedButton(
                            onPressed: _markPresentForExam,
                            child: Text('Mark Present'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _buildStudentInfo(),
          ],
        ),
      ),
    );
  }
}

