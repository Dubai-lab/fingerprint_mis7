import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

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

  Future<void> _exportToExcel() async {
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage permission is required to export Excel file')),
      );
      return;
    }

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['MarkSheet'];

    // Add header row
    sheetObject.cell(CellIndex.indexByString("A1")).value = "S/N" as CellValue?;
    sheetObject.cell(CellIndex.indexByString("B1")).value = "Reg No." as CellValue?;
    sheetObject.cell(CellIndex.indexByString("C1")).value = "Name" as CellValue?;
    sheetObject.cell(CellIndex.indexByString("D1")).value = "Attendance/10" as CellValue?;

    // Add student data rows
    for (int i = 0; i < _students.length; i++) {
      final student = _students[i];
      final studentId = student['studentId'] ?? '';
      final fullName = student['fullName'] ?? '';
      final attendanceScore = _calculateAttendanceScore(studentId);

      sheetObject.cell(CellIndex.indexByString("A${i + 2}")).value = (i + 1) as CellValue?;
      sheetObject.cell(CellIndex.indexByString("B${i + 2}")).value = studentId;
      sheetObject.cell(CellIndex.indexByString("C${i + 2}")).value = fullName;
      sheetObject.cell(CellIndex.indexByString("D${i + 2}")).value = attendanceScore as CellValue?;
    }

    // Save file
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot access storage directory')),
      );
      return;
    }

    String filePath = '${directory.path}/MarkSheet_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final fileBytes = excel.encode();
    if (fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to encode Excel file')),
      );
      return;
    }

    final file = File(filePath);
    await file.writeAsBytes(fileBytes);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Excel file saved at $filePath')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mark Sheet'),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            tooltip: 'Export to Excel',
            onPressed: _exportToExcel,
          ),
        ],
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

