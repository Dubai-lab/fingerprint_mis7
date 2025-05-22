import 'package:fingerprint_mis7/screens/student/join_courses_page.dart';
import 'package:fingerprint_mis7/screens/student/joined_courses_page.dart';
import 'package:fingerprint_mis7/screens/student/student_attendance_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart';
import '../student/student_profile_page.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Student Dashboard'),
        backgroundColor: Colors.teal.shade700,
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.teal.shade50,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade700, Colors.teal.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: FutureBuilder(
                  future: Future.value(FirebaseAuth.instance.currentUser),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    final photoUrl = user?.photoURL;
                    final displayName = user?.displayName;
                    final email = user?.email ?? '';
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null ? Icon(Icons.person, size: 40, color: Colors.white) : null,
                          backgroundColor: Colors.teal.shade900,
                        ),
                        SizedBox(height: 10),
                        Text(
                          displayName != null && displayName.isNotEmpty ? displayName : email,
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                ),
              ),
              ListTile(
                leading: Icon(Icons.person, color: Colors.teal.shade700),
                title: Text('Profile', style: TextStyle(color: Colors.teal.shade900)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => StudentProfilePage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.book, color: Colors.teal.shade700),
                title: Text('Join Courses', style: TextStyle(color: Colors.teal.shade900)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => JoinCoursesPage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.library_books, color: Colors.teal.shade700),
                title: Text('Joined Courses', style: TextStyle(color: Colors.teal.shade900)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => JoinedCoursesPage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.check_circle_outline, color: Colors.teal.shade700),
                title: Text('My Attendance & Exams', style: TextStyle(color: Colors.teal.shade900)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => StudentAttendancePage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red.shade700),
                title: Text('Logout', style: TextStyle(color: Colors.red.shade700)),
                onTap: () {
                  Navigator.of(context).pop();
                  _logout(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
