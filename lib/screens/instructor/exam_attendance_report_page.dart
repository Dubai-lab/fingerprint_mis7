import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ExamAttendanceReportPage extends StatefulWidget {
  @override
  _ExamAttendanceReportPageState createState() => _ExamAttendanceReportPageState();
}

class _ExamAttendanceReportPageState extends State<ExamAttendanceReportPage> {
  String? _selectedCourseId;
  String _selectedExamType = 'Exam';
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _loading = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    setState(() {
      _loading = true;
    });
    try {
      final user = FirebaseFirestore.instance;
      final userId = FirebaseFirestore.instance.app.options.projectId; // Placeholder, replace with actual user ID retrieval
      final coursesSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where('assignedInstructorId', isEqualTo: userId)
          .get();

      final courses = coursesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': doc.id, // Use courseId as name since exam_attendance uses courseId
          'code': '', // No code available
        };
      }).toList();

      setState(() {
        _courses = courses;
        if (courses.isNotEmpty) {
          _selectedCourseId = courses[0]['id'];
        }
      });
      await _fetchAttendanceRecords();
    } catch (e) {
      setState(() {
        _status = 'Failed to fetch courses: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchAttendanceRecords() async {
    if (_selectedCourseId == null) return;
    setState(() {
      _loading = true;
      _attendanceRecords = [];
      _status = '';
    });
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snapshot = await FirebaseFirestore.instance
          .collection('exam_attendance')
          .where('courseId', isEqualTo: _selectedCourseId)
          .where('examType', isEqualTo: _selectedExamType)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .get();

      final records = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'studentId': data['studentId'] ?? '',
          'status': data['status'] ?? '',
          'timestamp': data['timestamp'] != null
              ? (data['timestamp'] as Timestamp).toDate()
              : null,
        };
      }).toList();

      setState(() {
        _attendanceRecords = records;
        if (records.isEmpty) {
          _status = 'No attendance records found for selected course and exam type.';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to fetch attendance records: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _onCourseChanged(String? courseId) {
    setState(() {
      _selectedCourseId = courseId;
    });
    _fetchAttendanceRecords();
  }

  void _onExamTypeChanged(String? examType) {
    if (examType == null) return;
    setState(() {
      _selectedExamType = examType;
    });
    _fetchAttendanceRecords();
  }

  void _downloadReport() {
    // Implement CSV or PDF generation and download logic here
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Download feature not implemented yet')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    return Scaffold(
      appBar: AppBar(
        title: Text('Exam Attendance Report'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_loading) LinearProgressIndicator(),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCourseId,
                    decoration: InputDecoration(
                      labelText: 'Select Course',
                      border: OutlineInputBorder(),
                    ),
                    items: _courses.map((course) {
                      return DropdownMenuItem<String>(
                        value: course['id'],
                        child: Text('${course['courseId']} (${course['courseId']})'),
                      );
                    }).toList(),
                    onChanged: _onCourseChanged,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
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
                    onChanged: _onExamTypeChanged,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _downloadReport,
              icon: Icon(Icons.download),
              label: Text('Download Report'),
            ),
            SizedBox(height: 16),
            Expanded(
              child: _attendanceRecords.isEmpty
                  ? Center(child: Text(_status.isEmpty ? 'No data' : _status))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text('Student ID')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Timestamp')),
                        ],
                        rows: _attendanceRecords.map((record) {
                          final timestamp = record['timestamp'] as DateTime?;
                          return DataRow(cells: [
                            DataCell(Text(record['studentId'] ?? '')),
                            DataCell(Text(record['status'] ?? '')),
                            DataCell(Text(timestamp != null ? dateFormat.format(timestamp) : '')),
                          ]);
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
