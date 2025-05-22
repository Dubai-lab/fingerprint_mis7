import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminStudentCourseManagementPage extends StatefulWidget {
  final String? initialStudentId;

  const AdminStudentCourseManagementPage({Key? key, this.initialStudentId}) : super(key: key);

  @override
  _AdminStudentCourseManagementPageState createState() => _AdminStudentCourseManagementPageState();
}

class _AdminStudentCourseManagementPageState extends State<AdminStudentCourseManagementPage> {
  final TextEditingController _studentIdController = TextEditingController();
  List<Map<String, dynamic>> _joinedCourses = [];
  List<Map<String, dynamic>> _availableCourses = [];
  String _status = '';
  bool _loading = false;
  String? _searchedStudentId;
  Map<String, dynamic>? _studentInfo;

  @override
  void initState() {
    super.initState();
    if (widget.initialStudentId != null) {
      _studentIdController.text = widget.initialStudentId!;
      _searchStudentCourses();
    }
  }

  Future<void> _searchStudentCourses() async {
    final studentId = _studentIdController.text.trim();
    if (studentId.isEmpty) {
      setState(() {
        _status = 'Please enter a student ID';
        _joinedCourses = [];
        _availableCourses = [];
        _searchedStudentId = null;
        _studentInfo = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _status = '';
      _joinedCourses = [];
      _availableCourses = [];
      _searchedStudentId = null;
      _studentInfo = null;
    });

    try {
      // Check if studentId exists in students collection
      final studentSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (studentSnapshot.docs.isEmpty) {
        setState(() {
          _status = 'No student found with ID $studentId';
          _loading = false;
          _joinedCourses = [];
          _availableCourses = [];
          _searchedStudentId = null;
          _studentInfo = null;
        });
        return;
      }

      final studentData = studentSnapshot.docs.first.data();

      setState(() {
        _searchedStudentId = studentId;
        _studentInfo = studentData;
      });

      // Fetch joined courses for the student
      final joinedSnapshot = await FirebaseFirestore.instance
          .collection('joined_courses')
          .where('studentId', isEqualTo: studentId)
          .get();

      final joinedCourseIds = joinedSnapshot.docs.map((doc) => doc['courseId'] as String).toSet();

      final joinedCourses = <Map<String, dynamic>>[];
      for (var doc in joinedSnapshot.docs) {
        final data = doc.data();
        joinedCourses.add({
          'courseId': data['courseId'] ?? '',
          'fullName': data['fullName'] ?? '',
        });
      }

      // Fetch all courses
      final allCoursesSnapshot = await FirebaseFirestore.instance.collection('courses').get();
      final allCourses = allCoursesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Course',
          'code': data['code'] ?? '',
        };
      }).toList();

      // Determine available courses the student has not joined
      final availableCourses = allCourses.where((course) => !joinedCourseIds.contains(course['id'])).toList();

      setState(() {
        _joinedCourses = joinedCourses;
        _availableCourses = availableCourses;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to fetch courses: $e';
        _loading = false;
      });
    }
  }

  Future<void> _joinCourse(String courseId, String courseName) async {
    if (_searchedStudentId == null) return;

    try {
      await FirebaseFirestore.instance.collection('joined_courses').add({
        'studentId': _searchedStudentId,
        'courseId': courseId,
        'fullName': courseName,
      });
      setState(() {
        _status = 'Student joined to course successfully';
      });
      await _searchStudentCourses();
    } catch (e) {
      setState(() {
        _status = 'Failed to join course: $e';
      });
    }
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  Widget _buildStudentInfo() {
    if (_studentInfo == null) return SizedBox.shrink();
    return Card(
      color: Colors.blue.shade50,
      margin: EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        leading: Icon(Icons.person, color: Colors.blue.shade700),
        title: Text(
          '${_studentInfo!['firstName'] ?? ''} ${_studentInfo!['lastName'] ?? ''}',
          style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'ID: ${_studentInfo!['studentId'] ?? ''}\nEmail: ${_studentInfo!['email'] ?? ''}',
          style: TextStyle(color: Colors.blue.shade700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Course Management'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _studentIdController,
              decoration: InputDecoration(
                labelText: 'Enter Student ID',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search, color: Colors.blue.shade700),
                  onPressed: _searchStudentCourses,
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade700),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade300),
                ),
              ),
              onSubmitted: (_) => _searchStudentCourses(),
            ),
            _buildStudentInfo(),
            if (_loading) CircularProgressIndicator(color: Colors.blue.shade700),
            if (_status.isNotEmpty) Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(_status, style: TextStyle(color: Colors.red)),
            ),
            if (!_loading && _searchedStudentId != null) ...[
              Text('Joined Courses:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
              _joinedCourses.isEmpty
                  ? Text('No courses joined', style: TextStyle(color: Colors.blueGrey))
                  : Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _joinedCourses.length,
                        itemBuilder: (context, index) {
                          final course = _joinedCourses[index];
                          return Card(
                            color: Colors.green.shade50,
                            margin: EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(course['fullName'] ?? '', style: TextStyle(color: Colors.green.shade900)),
                              subtitle: Text('Course ID: ${course['courseId']}', style: TextStyle(color: Colors.green.shade700)),
                            ),
                          );
                        },
                      ),
                    ),
              SizedBox(height: 20),
              Text('Available Courses:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
              _availableCourses.isEmpty
                  ? Text('No available courses to join', style: TextStyle(color: Colors.blueGrey))
                  : Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableCourses.length,
                        itemBuilder: (context, index) {
                          final course = _availableCourses[index];
                          return Card(
                            color: Colors.orange.shade50,
                            margin: EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text('${course['name']} (${course['code']})', style: TextStyle(color: Colors.orange.shade900)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                ),
                                onPressed: () => _joinCourse(course['id'], course['name']),
                                child: Text('Join'),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}
