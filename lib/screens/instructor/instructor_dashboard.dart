import 'package:fingerprint_mis7/screens/instructor/completed_courses_page.dart';
import 'package:fingerprint_mis7/screens/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/login_page.dart';
import 'student_attendance_page.dart';
import 'course_students_page.dart';
import 'mark_sheet_page.dart';

class InstructorDashboard extends StatelessWidget {
  Future<String?> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return user.displayName ?? user.email;
  }

  Stream<QuerySnapshot> _fetchAssignedCourses() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('courses')
        .where('assignedInstructorId', isEqualTo: user.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    Future<void> _logout() async {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Instructor Dashboard'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.blue.shade50,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: FutureBuilder(
                  future: _fetchUserName(),
                  builder: (context, snapshot) {
                    final user = FirebaseAuth.instance.currentUser;
                    final photoUrl = user?.photoURL;
                    final fullName = snapshot.data as String?;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null ? Icon(Icons.person, size: 40) : null,
                        ),
                        SizedBox(height: 10),
                        Text(
                          fullName ?? user?.email ?? '',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    );
                  },
                ),
              ),
              ListTile(
                leading: Icon(Icons.person),
                title: Text('Profile'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ProfilePage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.assignment_turned_in),
                title: Text('Student Attendance'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => StudentAttendancePage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.group),
                title: Text('Course Students'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => CourseStudentsPage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.list_alt),
                title: Text('Mark Sheet'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => MarkSheetPage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.list_alt),
                title: Text('Completed Courses'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => CompletedCoursesPage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.logout),
                title: Text('Logout'),
                onTap: () {
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchAssignedCourses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No courses assigned',
                style: TextStyle(fontSize: 18),
              ),
            );
          }
          final courses = snapshot.data!.docs;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: EdgeInsets.all(16),
                  child: Text(
                    'Welcome, Instructor!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 2 / 3,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final course = courses[index].data() as Map<String, dynamic>;
                      final courseName = course['name'] ?? 'Unnamed Course';
                      final courseCode = course['code'] ?? '';
                      final startDate = course['startDate'] != null
                          ? (course['startDate'] as Timestamp).toDate()
                          : null;
                      final endDate = course['endDate'] != null
                          ? (course['endDate'] as Timestamp).toDate()
                          : null;
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                courseName,
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Code: $courseCode',
                                style: TextStyle(fontSize: 18, color: Colors.grey[800]),
                              ),
                              SizedBox(height: 16),
                              Text(
                                startDate != null && endDate != null
                                    ? 'Dates: ${startDate.toLocal().toString().split(' ')[0]} - ${endDate.toLocal().toString().split(' ')[0]}'
                                    : 'Dates: N/A',
                                style: TextStyle(fontSize: 18, color: Colors.grey[800]),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: courses.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
