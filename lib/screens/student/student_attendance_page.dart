import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StudentAttendancePage extends StatefulWidget {
  const StudentAttendancePage({Key? key}) : super(key: key);

  @override
  _StudentAttendancePageState createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  List<Map<String, dynamic>> _joinedCourses = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchJoinedCourses();
  }

  Future<void> _fetchJoinedCourses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final joinedSnapshot = await FirebaseFirestore.instance
        .collection('joined_courses')
        .where('studentId', isEqualTo: user.uid)
        .get();

    final courses = joinedSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'courseId': data['courseId'] ?? '',
        'fullName': data['fullName'] ?? '',
      };
    }).toList();

    setState(() {
      _joinedCourses = courses;
    });

    _fetchAttendanceRecords();
  }

  Future<void> _fetchAttendanceRecords() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _attendanceRecords = [];
    });

    final attendanceSnapshot = await FirebaseFirestore.instance
        .collection('exam_attendance')
        .where('studentId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .get();

    final records = attendanceSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'courseName': data['courseName'] ?? '',
        'examType': data['examType'] ?? '',
        'status': data['status'] ?? '',
        'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
      };
    }).toList();

    setState(() {
      _attendanceRecords = records;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Attendance & Exams'),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _attendanceRecords.isEmpty
              ? Center(child: Text('No attendance records found.'))
              : ListView.builder(
                  itemCount: _attendanceRecords.length,
                  itemBuilder: (context, index) {
                    final record = _attendanceRecords[index];
                    final timestamp = record['timestamp'] as DateTime?;
                    final formattedDate = timestamp != null
                        ? DateFormat('yyyy-MM-dd HH:mm').format(timestamp)
                        : 'Unknown date';
                    return ListTile(
                      title: Text('${record['courseName']} - ${record['examType']}'),
                      subtitle: Text('Status: ${record['status']}\nDate: $formattedDate'),
                    );
                  },
                ),
    );
  }
}
