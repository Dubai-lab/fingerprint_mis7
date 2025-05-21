import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_attendance_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssignedCoursesSelectionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Select Course'),
        ),
        body: Center(
          child: Text('User not logged in'),
        ),
      );
    }

    final Stream<QuerySnapshot> assignedCoursesStream = FirebaseFirestore.instance
        .collection('courses')
        .where('assignedInstructorId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text('Select Course for Attendance'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: assignedCoursesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading courses'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final courses = snapshot.data?.docs ?? [];
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
              return ListTile(
                title: Text('$courseName ($courseCode)'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => StudentAttendancePage(),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
