import 'package:fingerprint_mis7/screens/auth/register/invigilator_registration_page.dart';
import 'package:fingerprint_mis7/screens/course/create_course_page.dart';
import 'package:fingerprint_mis7/screens/course/manage_course_page.dart';
import 'package:flutter/material.dart';
import 'students_page.dart';
import 'professors_page.dart';
import 'dashboard_summary_cards.dart';
import '../exam/exam_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart';
import 'student_verification_page.dart';
import '../../screens/auth/register/student_registration_page.dart';
import '../profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../screens/auth/register/instructor_registration_page.dart';
import '../../screens/admin/admin_student_course_management_page.dart';

class AdminDashboard extends StatelessWidget {
  Future<String?> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('admins')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        final firstName = data['firstName'] ?? '';
        final middleName = data['middleName'] ?? '';
        final lastName = data['lastName'] ?? '';
        return [firstName, middleName, lastName].where((s) => s.isNotEmpty).join(' ');
      }
      return user.displayName ?? user.email;
    } catch (e) {
      return user.displayName ?? user.email;
    }
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
        title: Text('Admin Dashboard'),
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
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text('User', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: Icon(Icons.person, color: Colors.blueGrey),
                title: Text('Profile'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => ProfilePage()),
                  );
                },
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text('Students', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: Icon(Icons.verified_user, color: Colors.blueGrey),
                title: Text('Student Verification'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => StudentVerificationPage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.person_add, color: Colors.blueGrey),
                title: Text('Student Registration'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => StudentRegistrationPage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.group, color: Colors.blueGrey),
                title: Text('Manage Students'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => StudentsPage()),
                  );
                },
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text('Professors', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: Icon(Icons.school, color: Colors.blueGrey),
                title: Text('Instructor Registration'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => InstructorRegistrationPage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.person, color: Colors.blueGrey),
                title: Text('Manage Professors'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => ProfessorsPage()),
                  );
                },
              ),
              Divider(),
              ListTile(
  leading: Icon(Icons.app_registration, color: Colors.blueGrey),
  title: Text('Invigilator Registration'),
  onTap: () {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => InvigilatorRegistrationPage()),
    );
  },
),
Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text('Courses', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
              ),
              ExpansionTile(
                leading: Icon(Icons.book, color: Colors.blueGrey),
                title: Text('Course'),
                children: [
                  ListTile(
                    leading: Icon(Icons.add, color: Colors.blueGrey),
                    title: Text('Create Course'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => CreateCoursePage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.manage_accounts, color: Colors.blueGrey),
                    title: Text('Manage Courses'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => ManageCoursePage()),
                      );
                    },
                  ),
                ],
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.assignment, color: Colors.blueGrey),
                title: Text('Exam Page'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => ExamPage()),
                  );
                },
              ),
             
              Divider(),
              ListTile(
                leading: Icon(Icons.search, color: Colors.blueGrey),
                title: Text('Student Course Management'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => AdminStudentCourseManagementPage(initialStudentId: '',)),
                  );
                },
              ),
               Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.redAccent),
                title: Text('Logout', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Welcome to the Admin Dashboard',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            DashboardSummaryCards(),
            SizedBox(height: 20),
            // Removed Student ID search bar as per user request
          ],
        ),
      ),
    );
  }
}
