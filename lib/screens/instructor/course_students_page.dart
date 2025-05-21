import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourseStudentsPage extends StatefulWidget {
  @override
  _CourseStudentsPageState createState() => _CourseStudentsPageState();
}

class _CourseStudentsPageState extends State<CourseStudentsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final String _instructorUid;

  @override
  void initState() {
    super.initState();
    _instructorUid = _auth.currentUser?.uid ?? '';
  }

  Stream<QuerySnapshot> _fetchAssignedCourses() {
    return FirebaseFirestore.instance
        .collection('courses')
        .where('assignedInstructorId', isEqualTo: _instructorUid)
        .snapshots();
  }

  Stream<QuerySnapshot> _fetchStudentsForCourse(String courseId) {
    return FirebaseFirestore.instance
        .collection('joined_courses')
        .where('courseId', isEqualTo: courseId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Students Joined Courses'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchAssignedCourses(),
        builder: (context, courseSnapshot) {
          if (courseSnapshot.hasError) {
            return Center(child: Text('Error loading courses'));
          }
          if (courseSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final courses = courseSnapshot.data?.docs ?? [];
          if (courses.isEmpty) {
            return Center(child: Text('No courses assigned'));
          }
          return ListView.builder(
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final courseDoc = courses[index];
              final courseData = courseDoc.data() as Map<String, dynamic>;
              final courseName = courseData['name'] ?? 'Unnamed Course';
              final courseCode = courseData['code'] ?? '';
              return ExpansionTile(
                title: Text('$courseName ($courseCode)'),
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: _fetchStudentsForCourse(courseDoc.id),
                    builder: (context, studentSnapshot) {
                      if (studentSnapshot.hasError) {
                        return ListTile(
                          title: Text('Error loading students'),
                        );
                      }
                      if (studentSnapshot.connectionState == ConnectionState.waiting) {
                        return ListTile(
                          title: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final students = studentSnapshot.data?.docs ?? [];
                      if (students.isEmpty) {
                        return ListTile(
                          title: Text('No students have joined this course'),
                        );
                      }
                      return Column(
                        children: students.map((studentDoc) {
                          final studentData = studentDoc.data() as Map<String, dynamic>;
                          final studentId = studentData['studentId'] ?? 'Unknown ID';
                          final fullName = studentData['fullName'] ?? 'Unnamed Student';
                          final joinedAt = (studentData['joinedAt'] as Timestamp?)?.toDate();

                          return ListTile(
                            title: Text(fullName),
                            subtitle: Text('Student ID: $studentId\nJoined at: ${joinedAt != null ? joinedAt.toLocal().toString() : 'N/A'}'),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
