import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InstructorRegistrationPage extends StatefulWidget {
  @override
  _InstructorRegistrationPageState createState() => _InstructorRegistrationPageState();
}

class _InstructorRegistrationPageState extends State<InstructorRegistrationPage> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _status = 'Idle';

  Future<void> _registerInstructor() async {
    final userId = _userIdController.text.trim();
    final firstName = _firstNameController.text.trim();
    final middleName = _middleNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (userId.isEmpty) {
      setState(() {
        _status = 'Please enter user ID';
      });
      return;
    }
    if (firstName.isEmpty) {
      setState(() {
        _status = 'Please enter first name';
      });
      return;
    }
    if (lastName.isEmpty) {
      setState(() {
        _status = 'Please enter last name';
      });
      return;
    }
    if (email.isEmpty) {
      setState(() {
        _status = 'Please enter email';
      });
      return;
    }
    if (password.isEmpty) {
      setState(() {
        _status = 'Please enter password';
      });
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCredential.user?.uid;

      final docRef = FirebaseFirestore.instance.collection('instructors').doc(userId);
      await docRef.set({
        'userId': userId,
        'firstName': firstName,
        'middleName': middleName.isEmpty ? null : middleName,
        'lastName': lastName,
        'email': email,
        'uid': uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() {
        _status = 'Instructor registered successfully';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _status = 'Firebase Auth error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to register instructor: $e';
      });
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Instructor Registration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _userIdController,
                decoration: InputDecoration(
                  labelText: 'User ID',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _middleNameController,
                decoration: InputDecoration(
                  labelText: 'Middle Name (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
             
              SizedBox(height: 20),
              Text('Status: $_status'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _registerInstructor,
                child: Text('Register Instructor'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
