import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ExamAttendanceReportPage extends StatefulWidget {
  const ExamAttendanceReportPage({Key? key}) : super(key: key);

  @override
  _ExamAttendanceReportPageState createState() => _ExamAttendanceReportPageState();
}

class _ExamAttendanceReportPageState extends State<ExamAttendanceReportPage> {
  String? _selectedCourseId;
  String _selectedExamType = 'Exam';
  List<Map<String, dynamic>> _assignedCourses = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _loading = false;

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
        .where('assignedInvigilatorId', isEqualTo: user.uid)
        .get();

    final courses = coursesSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] ?? 'Unnamed Course',
        'code': data['code'] ?? '',
      };
    }).toList();

    setState(() {
      _assignedCourses = courses;
      if (courses.isNotEmpty) {
        _selectedCourseId = courses[0]['id'];
        _fetchAttendanceRecords();
      }
    });
  }

  Future<void> _fetchAttendanceRecords() async {
    if (_selectedCourseId == null) return;

    setState(() {
      _loading = true;
      _attendanceRecords = [];
    });

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    final attendanceSnapshot = await FirebaseFirestore.instance
        .collection('exam_attendance')
        .where('courseId', isEqualTo: _selectedCourseId)
        .where('examType', isEqualTo: _selectedExamType)
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThan: endOfDay)
        .get();

    final records = attendanceSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'studentId': data['studentId'] ?? '',
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

  void _onCourseChanged(String? newCourseId) {
    if (newCourseId == null) return;
    setState(() {
      _selectedCourseId = newCourseId;
    });
    _fetchAttendanceRecords();
  }

  void _onExamTypeChanged(String? newExamType) {
    if (newExamType == null) return;
    setState(() {
      _selectedExamType = newExamType;
    });
    _fetchAttendanceRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exam Attendance Report'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedCourseId,
                    isExpanded: true,
                    hint: Text('Select Course'),
                    items: _assignedCourses.map((course) {
                      return DropdownMenuItem<String>(
                        value: course['id'],
                        child: Text('${course['name']} (${course['code']})'),
                      );
                    }).toList(),
                    onChanged: _onCourseChanged,
                  ),
                ),
                SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedExamType,
                  items: ['Exam', 'CAT'].map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: _onExamTypeChanged,
                ),
              ],
            ),
            SizedBox(height: 16),
            _loading
                ? Center(child: CircularProgressIndicator())
                : Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('S/N')),
                          DataColumn(label: Text('Student ID')),
                          DataColumn(label: Text('Course Name')),
                          DataColumn(label: Text('Exam Type')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Timestamp')),
                        ],
                        rows: List.generate(_attendanceRecords.length, (index) {
                          final record = _attendanceRecords[index];
                          final timestamp = record['timestamp'] as DateTime?;
                          final formattedTime = timestamp != null
                              ? DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)
                              : '';
                          return DataRow(cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(Text(record['studentId'] ?? '')),
                            DataCell(Text(record['courseName'] ?? '')),
                            DataCell(Text(record['examType'] ?? '')),
                            DataCell(Text(record['status'] ?? '')),
                            DataCell(Text(formattedTime)),
                          ]);
                        }),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
