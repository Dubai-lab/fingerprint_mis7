import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinCoursesPage extends StatefulWidget {
  @override
  _JoinCoursesPageState createState() => _JoinCoursesPageState();
}

class _JoinCoursesPageState extends State<JoinCoursesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = _auth.currentUser?.uid ?? '';
  }

  Future<void> _joinCourse(String courseId) async {
    final now = DateTime.now();
    final courseDoc = FirebaseFirestore.instance.collection('courses').doc(courseId);
    final joinedCoursesCollection = FirebaseFirestore.instance.collection('joined_courses');

    try {
      // Fetch student info from students collection
      final studentQuerySnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('uid', isEqualTo: _uid)
          .limit(1)
          .get();
      if (studentQuerySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Student data not found')),
        );
        return;
      }
      final studentData = studentQuerySnapshot.docs.first.data();
      final studentId = studentData['studentId'] ?? '';
      final firstName = studentData['firstName'] ?? '';
      final lastName = studentData['lastName'] ?? '';
      final department = studentData['department'] ?? '';
      final fullName = (firstName + ' ' + lastName).trim();

      // Add to joined_courses collection with student info and course info
      final courseSnapshot = await courseDoc.get();
      if (!courseSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Course no longer exists')),
        );
        return;
      }
      final courseData = courseSnapshot.data()!;
      await joinedCoursesCollection.add({
        'studentUid': _uid,
        'studentId': studentId,
        'fullName': fullName,
        'department': department,
        'courseId': courseId,
        'courseName': courseData['name'],
        'courseCode': courseData['code'],
        'startDate': courseData['startDate'],
        'endDate': courseData['endDate'],
        'assignedInstructorId': courseData['assignedInstructorId'],
        'joinedAt': now,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully joined the course')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join course: $e')),
      );
    }
  }

  Stream<QuerySnapshot> _fetchAvailableCourses() {
    final now = DateTime.now();

    return FirebaseFirestore.instance
        .collection('courses')
        .where('assignedInstructorId', isNotEqualTo: null)
        .where('endDate', isGreaterThan: now)
        .snapshots();
  }

  Future<List<String>> _fetchJoinedCourseIds() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('joined_courses')
        .where('studentUid', isEqualTo: _uid)
        .get();
    return snapshot.docs.map((doc) => doc['courseId'] as String).toList();
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
        title: Text('Join Courses'),
        backgroundColor: Colors.teal.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchAvailableCourses(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading courses', style: TextStyle(color: Colors.red.shade700)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Colors.teal.shade700));
          }
          final courses = snapshot.data?.docs ?? [];
          return FutureBuilder<List<String>>(
            future: _fetchJoinedCourseIds(),
            builder: (context, joinedSnapshot) {
              if (!joinedSnapshot.hasData) {
                return Center(child: CircularProgressIndicator(color: Colors.teal.shade700));
              }
              final joinedCourseIds = joinedSnapshot.data!;
              final availableCourses = courses.where((doc) => !joinedCourseIds.contains(doc.id)).toList();

              if (availableCourses.isEmpty) {
                return Center(child: Text('No courses available to join', style: TextStyle(color: Colors.teal.shade700)));
              }

              return ListView.builder(
                itemCount: availableCourses.length,
                itemBuilder: (context, index) {
                  final doc = availableCourses[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final courseName = data['name'] ?? '';
                  final courseCode = data['code'] ?? '';
                  final startDate = (data['startDate'] as Timestamp?)?.toDate();
                  final endDate = (data['endDate'] as Timestamp?)?.toDate();
                  final assignedInstructorId = data['assignedInstructorId'];

                  return FutureBuilder<String?>(
                    future: _fetchInstructorName(assignedInstructorId),
                    builder: (context, instructorSnapshot) {
                      final instructorName = instructorSnapshot.data ?? 'Unknown Instructor';
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        color: Colors.teal.shade50,
                        child: ListTile(
                          title: Text('$courseName ($courseCode)', style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Instructor: $instructorName\n'
                            'Start: ${startDate != null ? startDate.toLocal().toString().split(' ')[0] : 'N/A'}\n'
                            'End: ${endDate != null ? endDate.toLocal().toString().split(' ')[0] : 'N/A'}',
                            style: TextStyle(color: Colors.teal.shade700),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                            ),
                            onPressed: () {
                              final now = DateTime.now();
                              if (startDate != null && now.isAfter(startDate.add(Duration(hours: 48)))) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Join deadline has passed')),
                                );
                                return;
                              }
                              _joinCourse(doc.id);
                            },
                            child: Text('Join'),
                          ),
                        ),
                      );
                    },
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
