import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MarkSheetPage extends StatefulWidget {
  const MarkSheetPage({Key? key}) : super(key: key);

  @override
  _MarkSheetPageState createState() => _MarkSheetPageState();
}

class _MarkSheetPageState extends State<MarkSheetPage> {
  String? _selectedCourseId;
  List<QueryDocumentSnapshot> _assignedCourses = [];
  List<Map<String, dynamic>> _students = [];
  Map<String, int> _attendanceCount = {};

  @override
  void initState() {
    super.initState();
    _fetchAssignedCourses();
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
        _fetchStudentsAndAttendance(_selectedCourseId!);
      }
    });
  }

  Future<void> _fetchStudentsAndAttendance(String courseId) async {
    // Fetch students joined in the course
    final joinedSnapshot = await FirebaseFirestore.instance
        .collection('joined_courses')
        .where('courseId', isEqualTo: courseId)
        .get();

    final students = joinedSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'studentId': data['studentId'] ?? '',
        'fullName': data['fullName'] ?? '',
      };
    }).toList();

    // Fetch attendance records for the course
    final attendanceSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('courseId', isEqualTo: courseId)
        .where('status', isEqualTo: 'Present')
        .get();

    // Count attendance per student
    final attendanceCount = <String, int>{};
    for (var doc in attendanceSnapshot.docs) {
      final data = doc.data();
      final studentId = data['studentId'] as String?;
      if (studentId != null) {
        attendanceCount[studentId] = (attendanceCount[studentId] ?? 0) + 1;
      }
    }

    setState(() {
      _students = students;
      _attendanceCount = attendanceCount;
    });
  }

  void _onCourseChanged(String? newCourseId) {
    if (newCourseId == null) return;
    setState(() {
      _selectedCourseId = newCourseId;
      _students = [];
      _attendanceCount = {};
    });
    _fetchStudentsAndAttendance(newCourseId);
  }

  double _calculateAttendanceScore(String studentId) {
    // For simplicity, assume max attendance count is 10
    final count = _attendanceCount[studentId] ?? 0;
    return count > 10 ? 10 : count.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mark Sheet'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
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
              onChanged: _onCourseChanged,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('S/N')),
                  DataColumn(label: Text('Reg No.')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Attendance/10')),
                ],
                rows: List.generate(_students.length, (index) {
                  final student = _students[index];
                  final studentId = student['studentId'] ?? '';
                  final fullName = student['fullName'] ?? '';
                  final attendanceScore = _calculateAttendanceScore(studentId);
                  return DataRow(cells: [
                    DataCell(Text('${index + 1}')),
                    DataCell(Text(studentId)),
                    DataCell(Text(fullName)),
                    DataCell(Text(attendanceScore.toStringAsFixed(1))),
                  ]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
