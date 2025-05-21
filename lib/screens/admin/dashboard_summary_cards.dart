import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardSummaryCards extends StatefulWidget {
  @override
  _DashboardSummaryCardsState createState() => _DashboardSummaryCardsState();
}

class _DashboardSummaryCardsState extends State<DashboardSummaryCards> {
  int newStudentsCount = 0;
  int totalCoursesCount = 0;
  int totalProfessorsCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }

  Future<void> _fetchCounts() async {
    final now = DateTime.now();
    final oneMonthAgo = DateTime(now.year, now.month - 1, now.day);

    try {
      // Count new students registered in the last month
      final newStudentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('timestamp', isGreaterThanOrEqualTo: oneMonthAgo)
          .get();
      // Count total courses
      final totalCoursesSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .get();
      // Count total professors
      final totalProfessorsSnapshot = await FirebaseFirestore.instance
          .collection('instructors')
          .get();

      setState(() {
        newStudentsCount = newStudentsSnapshot.docs.length;
        totalCoursesCount = totalCoursesSnapshot.docs.length;
        totalProfessorsCount = totalProfessorsSnapshot.docs.length;
      });
    } catch (e) {
      // Handle errors if needed
    }
  }

  Widget _buildCard(String title, int count, String subtitle, IconData icon, Color iconColor) {
    return Card(
      elevation: 3,
      child: Container(
        width: 110,
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: iconColor),
            SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
            SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCard('New Students', newStudentsCount, '10% Higher Than Last Month', Icons.people, Colors.blue),
        _buildCard('Total Courses', totalCoursesCount, '07% Less Than Last Year', Icons.school, Colors.orange),
        _buildCard('Total Professors', totalProfessorsCount, '12% Higher Than Last Month', Icons.person, Colors.purple),
      ],
    );
  }
}
