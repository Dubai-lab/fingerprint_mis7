import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageCoursePage extends StatefulWidget {
  @override
  _ManageCoursePageState createState() => _ManageCoursePageState();
}

class _ManageCoursePageState extends State<ManageCoursePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _courseNameController = TextEditingController();
  final TextEditingController _courseCodeController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedDepartment;
  String? _selectedInstructorId;

  List<String> _departments = [];
  List<Map<String, dynamic>> _instructors = [];
  List<Map<String, dynamic>> _invigilators = [];
  String? _selectedInvigilatorId;

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
    _fetchInstructors();
    _fetchInvigilators();
  }

  Future<void> _fetchDepartments() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('students').get();
      final departmentsSet = <String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dept = data['department'];
        if (dept != null && dept is String && dept.isNotEmpty) {
          departmentsSet.add(dept);
        }
      }
      setState(() {
        _departments = ['All', ...departmentsSet.toList()];
        _selectedDepartment = 'All';
      });
    } catch (e) {
      print('Failed to fetch departments: $e');
    }
  }

  Future<void> _fetchInstructors() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('instructors').get();
      setState(() {
        _instructors = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': data['uid'],
            'name': (data['firstName'] ?? '') + ' ' + (data['lastName'] ?? ''),
          };
        }).toList();
      });
    } catch (e) {
      print('Failed to fetch instructors: $e');
    }
  }

  Future<void> _fetchInvigilators() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('invigilators').get();
      setState(() {
        _invigilators = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': data['uid'],
            'name': (data['firstName'] ?? '') + ' ' + (data['lastName'] ?? ''),
          };
        }).toList();
      });
    } catch (e) {
      print('Failed to fetch invigilators: $e');
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _createOrUpdateCourse([String? docId]) async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select both start and end dates')),
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('End date cannot be before start date')),
      );
      return;
    }
    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a department')),
      );
      return;
    }

    try {
      final courseData = {
        'name': _courseNameController.text.trim(),
        'code': _courseCodeController.text.trim(),
        'startDate': _startDate,
        'endDate': _endDate,
        'assignedInstructorId': _selectedInstructorId,
            'department': _selectedDepartment == 'All' ? null : _selectedDepartment,
            'createdAt': FieldValue.serverTimestamp(),
            'assignedInstructorId': _selectedInstructorId,
            'assignedInvigilatorId': _selectedInvigilatorId,
          };
          if (docId == null) {
            await FirebaseFirestore.instance.collection('courses').add(courseData);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Course created successfully')),
            );
          } else {
            await FirebaseFirestore.instance.collection('courses').doc(docId).update(courseData);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Course updated successfully')),
            );
          }
          _clearForm();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save course: $e')),
          );
        }
      }

  void _clearForm() {
    _formKey.currentState?.reset();
    _courseNameController.clear();
    _courseCodeController.clear();
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedDepartment = _departments.isNotEmpty ? _departments[0] : null;
      _selectedInstructorId = null;
    });
  }

  void _populateForm(Map<String, dynamic> courseData) {
    _courseNameController.text = courseData['name'] ?? '';
    _courseCodeController.text = courseData['code'] ?? '';
    _startDate = (courseData['startDate'] as Timestamp?)?.toDate();
    _endDate = (courseData['endDate'] as Timestamp?)?.toDate();
    _selectedDepartment = courseData['department'] ?? 'All';
    _selectedInstructorId = courseData['assignedInstructorId'];
  }

  Future<void> _deleteCourse(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('courses').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Course deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete course: $e')),
      );
    }
  }

  @override
  void dispose() {
    _courseNameController.dispose();
    _courseCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Courses'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('courses').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading courses'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                final courses = snapshot.data?.docs ?? [];
                if (courses.isEmpty) {
                  return Center(child: Text('No courses found'));
                }
                return ListView.builder(
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final doc = courses[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final courseName = data['name'] ?? '';
                    final courseCode = data['code'] ?? '';
                    final department = data['department'] ?? 'All';
                    final assignedInstructorId = data['assignedInstructorId'];
                    final assignedInstructor = _instructors.firstWhere(
                      (inst) => inst['id'] == assignedInstructorId,
                      orElse: () => {'name': 'Unassigned'},
                    );
                    return ListTile(
                      title: Text('$courseName ($courseCode)'),
                      subtitle: Text('Department: $department\nInstructor: ${assignedInstructor['name']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () {
                              _populateForm(data);
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Edit Course'),
                                  content: _buildForm(),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _clearForm();
                                      },
                                      child: Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        await _createOrUpdateCourse(doc.id);
                                        Navigator.of(context).pop();
                                      },
                                      child: Text('Save'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Confirm Delete'),
                                  content: Text('Are you sure you want to delete this course?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _deleteCourse(doc.id);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                _clearForm();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Create Course'),
                    content: _buildForm(),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _clearForm();
                        },
                        child: Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await _createOrUpdateCourse();
                          Navigator.of(context).pop();
                        },
                        child: Text('Create'),
                      ),
                    ],
                  ),
                );
              },
              child: Text('Add New Course'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _courseNameController,
              decoration: InputDecoration(
                labelText: 'Course Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.isEmpty ? 'Please enter course name' : null,
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _courseCodeController,
              decoration: InputDecoration(
                labelText: 'Course Code',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.isEmpty ? 'Please enter course code' : null,
            ),
            SizedBox(height: 8),
            ListTile(
              title: Text(_startDate == null ? 'Select Start Date' : 'Start Date: ${_startDate!.toLocal().toString().split(' ')[0]}'),
              trailing: Icon(Icons.calendar_today),
              onTap: () => _selectDate(context, true),
            ),
            ListTile(
              title: Text(_endDate == null ? 'Select End Date' : 'End Date: ${_endDate!.toLocal().toString().split(' ')[0]}'),
              trailing: Icon(Icons.calendar_today),
              onTap: () => _selectDate(context, false),
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDepartment,
              decoration: InputDecoration(
                labelText: 'Department',
                border: OutlineInputBorder(),
              ),
              items: _departments.map((dept) {
                return DropdownMenuItem<String>(
                  value: dept,
                  child: Text(dept),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDepartment = value;
                });
              },
              validator: (value) => value == null || value.isEmpty ? 'Please select a department' : null,
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedInstructorId,
              decoration: InputDecoration(
                labelText: 'Assign Instructor',
                border: OutlineInputBorder(),
              ),
              items: _instructors.map((inst) {
                return DropdownMenuItem<String>(
                  value: inst['id'],
                  child: Text(inst['name']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedInstructorId = value;
                });
              },
              isExpanded: true,
              hint: Text('Select Instructor'),
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedInvigilatorId,
              decoration: InputDecoration(
                labelText: 'Assign Invigilator',
                border: OutlineInputBorder(),
              ),
              items: _invigilators.map((inv) {
                return DropdownMenuItem<String>(
                  value: inv['id'],
                  child: Text(inv['name']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedInvigilatorId = value;
                });
              },
              isExpanded: true,
              hint: Text('Select Invigilator'),
            ),
          ],
        ),
      ),
    );
  }
}
