import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? user = FirebaseAuth.instance.currentUser;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;
  bool _isFetchingUserName = false;

  String? _fullName;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    if (user == null) return;

    setState(() {
      _isFetchingUserName = true;
    });

    try {
      // Query 'admins' collection where 'uid' equals current user's uid
      final adminSnapshot = await FirebaseFirestore.instance
          .collection('admins')
          .where('uid', isEqualTo: user!.uid)
          .limit(1)
          .get();

      if (adminSnapshot.docs.isNotEmpty) {
        final data = adminSnapshot.docs.first.data();
        final firstName = data['firstName'] ?? '';
        final middleName = data['middleName'] ?? '';
        final lastName = data['lastName'] ?? '';
        setState(() {
          _fullName = [firstName, middleName, lastName].where((s) => s.isNotEmpty).join(' ');
          _isFetchingUserName = false;
        });
        return;
      }

      // If not found in admins, check 'instructors' collection
      final instructorSnapshot = await FirebaseFirestore.instance
          .collection('instructors')
          .where('uid', isEqualTo: user!.uid)
          .limit(1)
          .get();

      if (instructorSnapshot.docs.isNotEmpty) {
        final data = instructorSnapshot.docs.first.data();
        final firstName = data['firstName'] ?? '';
        final middleName = data['middleName'] ?? '';
        final lastName = data['lastName'] ?? '';
        setState(() {
          _fullName = [firstName, middleName, lastName].where((s) => s.isNotEmpty).join(' ');
          _isFetchingUserName = false;
        });
        return;
      }

      // If not found in admins or instructors, fallback to displayName or email
      setState(() {
        _fullName = user!.displayName ?? user!.email;
        _isFetchingUserName = false;
      });
    } catch (e) {
      setState(() {
        _fullName = user!.displayName ?? user!.email;
        _isFetchingUserName = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null || user == null) return;

    setState(() {
      _uploading = true;
    });

    try {
      final storageRef = FirebaseStorage.instance.ref().child('profile_pictures').child('${user!.uid}.jpg');
      await storageRef.putFile(_imageFile!);
      final downloadUrl = await storageRef.getDownloadURL();

      await user!.updatePhotoURL(downloadUrl);
      await user!.reload();
      user = FirebaseAuth.instance.currentUser;

      setState(() {
        _uploading = false;
      });
    } catch (e) {
      setState(() {
        _uploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isFetchingUserName
            ? Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null ? Icon(Icons.person, size: 50) : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _uploading ? null : _pickImage,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue,
                              child: _uploading
                                  ? CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    )
                                  : Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text('Name: ${_fullName ?? 'N/A'}', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 10),
                  Text('Email: ${user?.email ?? 'N/A'}', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 10),
                  // Add more profile fields here as needed
                ],
              ),
      ),
    );
  }
}
