import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExamPage extends StatefulWidget {
  @override
  _ExamPageState createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  List<Map<String, dynamic>> _courses = [];
  String? _selectedCourseId;
  DateTime? _examDate;
  DateTime? _catDate;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('courses').get();
      final courses = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Course',
          'code': data['code'] ?? '',
        };
      }).toList();

      setState(() {
        _courses = courses;
        if (_courses.isNotEmpty) {
          _selectedCourseId = _courses[0]['id'];
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to fetch courses: $e';
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isExamDate) async {
    final initialDate = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: isExamDate ? (_examDate ?? initialDate) : (_catDate ?? initialDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        if (isExamDate) {
          _examDate = pickedDate;
        } else {
          _catDate = pickedDate;
        }
      });
    }
  }

  Future<void> _saveDates() async {
    if (_selectedCourseId == null) {
      setState(() {
        _status = 'Please select a course';
      });
      return;
    }
    if (_examDate == null && _catDate == null) {
      setState(() {
        _status = 'Please select at least one date';
      });
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance.collection('courses').doc(_selectedCourseId);
      final updateData = <String, dynamic>{};
      if (_examDate != null) {
        updateData['examDate'] = _examDate;
      }
      if (_catDate != null) {
        updateData['catDate'] = _catDate;
      }
      await docRef.update(updateData);
      setState(() {
        _status = 'Dates saved successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to save dates: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exam Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _courses.isEmpty
            ? Center(child: Text('No courses available'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Course:', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _selectedCourseId,
                    items: _courses.map((course) {
                      return DropdownMenuItem<String>(
                        value: course['id'],
                        child: Text('${course['name']} (${course['code']})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCourseId = value;
                      });
                    },
                  ),
                  SizedBox(height: 20),
                  Text('Set Exam Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Text(_examDate == null ? 'No date chosen' : _examDate!.toLocal().toString().split(' ')[0]),
                      SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: () => _selectDate(context, true),
                        child: Text('Choose Date'),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text('Set CAT Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Text(_catDate == null ? 'No date chosen' : _catDate!.toLocal().toString().split(' ')[0]),
                      SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: () => _selectDate(context, false),
                        child: Text('Choose Date'),
                      ),
                    ],
                  ),
                  SizedBox(height: 30),
                  Center(
                    child: ElevatedButton(
                      onPressed: _saveDates,
                      child: Text('Save Dates'),
                    ),
                  ),
                  SizedBox(height: 20),
                  Center(
                    child: Text(
                      _status,
                      style: TextStyle(color: _status.contains('Failed') ? Colors.red : Colors.green),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
