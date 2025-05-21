import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompletedCoursesPage extends StatelessWidget {
  const CompletedCoursesPage({Key? key}) : super(key: key);

  Stream<QuerySnapshot> _fetchCompletedCourses() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return FirebaseFirestore.instance
        .collection('courses')
        .where('endDate', isLessThan: todayDate)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Completed Courses'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchCompletedCourses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No completed courses found'));
          }
          final courses = snapshot.data!.docs;
          return ListView.builder(
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index].data() as Map<String, dynamic>;
              final courseName = course['name'] ?? 'Unnamed Course';
              final courseCode = course['code'] ?? '';
              final startDate = course['startDate'] != null
                  ? (course['startDate'] as Timestamp).toDate()
                  : null;
              final endDate = course['endDate'] != null
                  ? (course['endDate'] as Timestamp).toDate()
                  : null;
              return ListTile(
                title: Text('Course: $courseName'),
                subtitle: Text('Code: $courseCode\nDate: ' +
                    (startDate != null && endDate != null
                        ? '${startDate.toLocal().toString().split(' ')[0]} - ${endDate.toLocal().toString().split(' ')[0]}'
                        : 'N/A')),
              );
            },
          );
        },
      ),
    );
  }
}
