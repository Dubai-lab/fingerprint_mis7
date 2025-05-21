import 'package:fingerprint_mis7/screens/student/join_courses_page.dart';
import 'package:fingerprint_mis7/screens/student/joined_courses_page.dart';
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
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
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
                        child: photoUrl == null ? Icon(Icons.person, size: 40) : null,
                      ),
                      SizedBox(height: 10),
                      Text(
                        displayName != null && displayName.isNotEmpty ? displayName : email,
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
                  MaterialPageRoute(builder: (context) => StudentProfilePage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.book),
              title: Text('Join Courses'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => JoinCoursesPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.library_books),
              title: Text('Joined Courses'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => JoinedCoursesPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () {
                Navigator.of(context).pop();
                _logout(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
