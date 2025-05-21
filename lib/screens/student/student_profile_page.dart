import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({Key? key}) : super(key: key);

  @override
  _StudentProfilePageState createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  String? studentName;
  String? email;

  @override
  void initState() {
    super.initState();
    _fetchStudentProfile();
  }

  Future<void> _fetchStudentProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    email = user.email;

    final querySnapshot = await FirebaseFirestore.instance.collection('students').where('uid', isEqualTo: user.uid).limit(1).get();
    if (querySnapshot.docs.isNotEmpty) {
      final data = querySnapshot.docs.first.data();
      final firstName = data['firstName'] ?? '';
      final middleName = data['middleName'] ?? '';
      final lastName = data['lastName'] ?? '';
      final fullName = [firstName, middleName, lastName].where((s) => s.isNotEmpty).join(' ');
      setState(() {
        studentName = fullName.isNotEmpty ? fullName : 'No name available';
      });
    } else {
      setState(() {
        studentName = 'No name available';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${studentName ?? 'Loading...'}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('Email: ${email ?? 'Loading...'}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            // Add more profile fields here as needed
          ],
        ),
      ),
    );
  }
}
