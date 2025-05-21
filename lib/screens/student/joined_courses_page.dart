import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinedCoursesPage extends StatefulWidget {
  @override
  _JoinedCoursesPageState createState() => _JoinedCoursesPageState();
}

class _JoinedCoursesPageState extends State<JoinedCoursesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = _auth.currentUser?.uid ?? '';
  }

  Future<String?> _fetchInstructorName(String? instructorId) async {
    if (instructorId == null) return null;
    final snapshot = await FirebaseFirestore.instance
        .collection('instructors')
        .where('uid', isEqualTo: instructorId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final data = snapshot.docs.first.data();
    final firstName = data['firstName'] ?? '';
    final lastName = data['lastName'] ?? '';
    return '$firstName $lastName'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Joined Courses'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('joined_courses')
            .where('studentUid', isEqualTo: _uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading joined courses'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final joinedCourses = snapshot.data?.docs ?? [];
          if (joinedCourses.isEmpty) {
            return Center(child: Text('No joined courses found'));
          }
          return ListView.builder(
            itemCount: joinedCourses.length,
            itemBuilder: (context, index) {
              final doc = joinedCourses[index];
              final data = doc.data() as Map<String, dynamic>;
              final courseName = data['courseName'] ?? '';
              final courseCode = data['courseCode'] ?? '';
              final startDate = (data['startDate'] as Timestamp?)?.toDate();
              final endDate = (data['endDate'] as Timestamp?)?.toDate();
              final assignedInstructorId = data['assignedInstructorId'];

              return FutureBuilder<String?>(
                future: _fetchInstructorName(assignedInstructorId),
                builder: (context, instructorSnapshot) {
                  final instructorName = instructorSnapshot.data ?? 'Unknown Instructor';
                  return ListTile(
                    title: Text('$courseName ($courseCode)'),
                    subtitle: Text(
                      'Instructor: $instructorName\n'
                      'Start: ${startDate != null ? startDate.toLocal().toString().split(' ')[0] : 'N/A'}\n'
                      'End: ${endDate != null ? endDate.toLocal().toString().split(' ')[0] : 'N/A'}',
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
