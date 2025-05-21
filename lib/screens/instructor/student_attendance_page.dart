import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentAttendancePage extends StatefulWidget {
  @override
  _StudentAttendancePageState createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  static const platform = MethodChannel('com.example.fingerprint_mis7/usb_fingerprint');

  String _status = 'Idle';
  Uint8List? _scannedTemplate;
  Map<String, String> _students = {}; // studentId -> base64 fingerprint template
  Map<String, Map<String, dynamic>> _attendanceRecords = {}; // studentId -> attendance data

  String? _selectedCourseId;
  List<QueryDocumentSnapshot> _assignedCourses = [];

  @override
  void initState() {
    super.initState();
    platform.setMethodCallHandler(_handleNativeCalls);
    _loadRegisteredStudents();
    _loadTodayAttendance();
    _fetchAssignedCourses();
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
          _markAttendance(templateData);
        }
        break;
      default:
        break;
    }
  }

  Future<void> _fetchAssignedCourses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final coursesSnapshot = await FirebaseFirestore.instance
        .collection('courses')
        .where('assignedInstructorId', isEqualTo: user.uid)
        .get();

    setState(() {
      _assignedCourses = coursesSnapshot.docs;
      if (_assignedCourses.isNotEmpty) {
        _selectedCourseId = _assignedCourses.first.id;
      }
    });
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

  Future<void> _loadTodayAttendance() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .get();
      final Map<String, Map<String, dynamic>> records = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('studentId')) {
          records[data['studentId']] = data;
        }
      }
      setState(() {
        _attendanceRecords = records;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load attendance records: $e';
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
        _status = 'Scan fingerprint to mark attendance';
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = "Failed to generate template: '${e.message}'.";
      });
    }
  }

  Future<bool> _isStudentEnrolled(String studentId) async {
    if (_selectedCourseId == null) return false;
    final querySnapshot = await FirebaseFirestore.instance
        .collection('joined_courses')
        .where('courseId', isEqualTo: _selectedCourseId)
        .where('studentId', isEqualTo: studentId)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

  void _markAttendance(Uint8List scannedTemplate) async {
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
      final enrolled = await _isStudentEnrolled(bestMatchId);
      if (!enrolled) {
        setState(() {
          _status = 'Student $bestMatchId is not enrolled in the selected course. Attendance not marked.';
        });
        return;
      }
      try {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final existingAttendance = await FirebaseFirestore.instance
            .collection('attendance')
            .where('studentId', isEqualTo: bestMatchId)
            .where('courseId', isEqualTo: _selectedCourseId)
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .get();

        if (existingAttendance.docs.isNotEmpty) {
          setState(() {
            _status = 'Attendance already marked for student $bestMatchId today.';
          });
          return;
        }

        final docRef = FirebaseFirestore.instance.collection('attendance').doc();
        await docRef.set({
          'studentId': bestMatchId,
          'courseId': _selectedCourseId,
          'status': 'Present',
          'timestamp': FieldValue.serverTimestamp(),
        });
        setState(() {
          _status = 'Attendance marked Present for student $bestMatchId (score: $bestScore)';
          if (bestMatchId != null) {
            _attendanceRecords[bestMatchId] = {
              'studentId': bestMatchId,
              'status': 'Present',
              'timestamp': DateTime.now(),
            };
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attendance marked Present for student $bestMatchId')),
        );
      } catch (e) {
        setState(() {
          _status = 'Failed to mark attendance: $e';
        });
      }
    } else {
      setState(() {
        _status = 'No match found, attendance not marked';
      });
    }
  }

  Future<void> _markAbsentStudents() async {
    if (_selectedCourseId == null) {
      setState(() {
        _status = 'Please select a course first.';
      });
      return;
    }

    try {
      final enrolledSnapshot = await FirebaseFirestore.instance
          .collection('joined_courses')
          .where('courseId', isEqualTo: _selectedCourseId)
          .get();

      final enrolledStudentIds = enrolledSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['studentId'] as String)
          .toSet();

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('courseId', isEqualTo: _selectedCourseId)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .get();

      final attendedStudentIds = attendanceSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['studentId'] as String)
          .toSet();

      final absentStudentIds = enrolledStudentIds.difference(attendedStudentIds);

      final batch = FirebaseFirestore.instance.batch();
      final attendanceCollection = FirebaseFirestore.instance.collection('attendance');

      for (var studentId in absentStudentIds) {
        final docRef = attendanceCollection.doc();
        batch.set(docRef, {
          'studentId': studentId,
          'courseId': _selectedCourseId,
          'status': 'Absent',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      setState(() {
        _status = 'Marked ${absentStudentIds.length} students as absent.';
      });

      await _loadTodayAttendance();
    } catch (e) {
      setState(() {
        _status = 'Failed to mark absent students: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Attendance'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.blue.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              value: _selectedCourseId,
              hint: Text('Select Course'),
              isExpanded: true,
              items: _assignedCourses.map((courseDoc) {
                final courseData = courseDoc.data() as Map<String, dynamic>;
                final courseName = courseData['name'] ?? 'Unnamed Course';
                final courseCode = courseData['code'] ?? '';
                return DropdownMenuItem<String>(
                  value: courseDoc.id,
                  child: Text('$courseName ($courseCode)'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCourseId = value;
                });
              },
            ),
            SizedBox(height: 10),
            Text(
              'Status: $_status',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _openDevice,
                  icon: Icon(Icons.usb),
                  label: Text('Open Device'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.black,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _closeDevice,
                  icon: Icon(Icons.usb_off),
                  label: Text('Close Device'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.black,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _generateTemplate,
                  icon: Icon(Icons.fingerprint),
                  label: Text('Scan Fingerprint'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.black,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _markAbsentStudents,
                  icon: Icon(Icons.person_off),
                  label: Text('Mark Absent Students'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: _attendanceRecords.length,
                separatorBuilder: (context, index) => Divider(),
                itemBuilder: (context, index) {
                  final data = _attendanceRecords.values.elementAt(index);
                  final timestamp = data['timestamp'] as Timestamp?;
                  final timeString = timestamp != null
                      ? timestamp.toDate().toLocal().toString()
                      : 'Unknown time';
                  final status = data['status'] ?? 'Unknown';
                  Color statusColor;
                  IconData statusIcon;
                  switch (status) {
                    case 'Present':
                      statusColor = Colors.green;
                      statusIcon = Icons.check_circle;
                      break;
                    case 'Absent':
                      statusColor = Colors.red;
                      statusIcon = Icons.cancel;
                      break;
                    default:
                      statusColor = Colors.grey;
                      statusIcon = Icons.help;
                  }
                  return ListTile(
                    leading: Icon(statusIcon, color: statusColor),
                    title: Text('Student ID: ${data['studentId'] ?? ''}'),
                    subtitle: Text('Status: $status\nTime: $timeString'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

