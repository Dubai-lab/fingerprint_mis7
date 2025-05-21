import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart';
import '../exam/exam_verification_page.dart';
import 'invigilator_profile_page.dart';
import 'invigilator_settings_page.dart';
import 'invigilator_profile_page.dart';
import '../instructor/exam_attendance_report_page.dart';


class InvigilatorDashboard extends StatelessWidget {
  Future<String?> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    // You can extend this to fetch more user details from Firestore if needed
    return user.displayName ?? user.email;
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

    void _navigateToExamVerification() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ExamVerificationPage(),
        ),
      );
    }
    void _navigateToExamAttendanceReport() {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => ExamAttendanceReportPage(),
    ),
  );
}


    return Scaffold(
      appBar: AppBar(
        title: Text('Invigilator Dashboard'),
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
                    return SingleChildScrollView(
                      child: Column(
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
                      ),
                    );
                  },
                ),
              ),
              ListTile(
                leading: Icon(Icons.dashboard, color: Colors.blueGrey),
                title: Text('Dashboard'),
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: Icon(Icons.assignment, color: Colors.blueGrey),
                title: Text('Exam Verification'),
                onTap: () {
                  Navigator.of(context).pop();
                  _navigateToExamVerification();
                },
              ),
              ListTile(
  leading: Icon(Icons.report, color: Colors.blueGrey),
  title: Text('Exam Attendance Report'),
  onTap: () {
    Navigator.of(context).pop();
    _navigateToExamAttendanceReport();
  },
),

              
              // Add more invigilator-specific navigation items here
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, Invigilator!',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
            ),
            SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildDashboardCard(
                    context,
                    icon: Icons.assignment_turned_in,
                    title: 'Exam Verification',
                    color: Colors.blue.shade600,
                    onTap: _navigateToExamVerification,
                  ),
                  _buildDashboardCard(
                    context,
                    icon: Icons.person,
                    title: 'Profile',
                    color: Colors.blue.shade400,
                    onTap: () {
                      
                    },
                  ),
                  _buildDashboardCard(
                    context,
                    icon: Icons.settings,
                    title: 'Settings',
                    color: Colors.blue.shade300,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => InvigilatorSettingsPage()),
                      );
                    },
                  ),
                  _buildDashboardCard(
  context,
  icon: Icons.report,
  title: 'Attendance Report',
  color: Colors.blue.shade500,
  onTap: _navigateToExamAttendanceReport,
),

                  _buildDashboardCard(
                    context,
                    icon: Icons.logout,
                    title: 'Logout',
                    color: Colors.redAccent,
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context,
      {required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.white),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
