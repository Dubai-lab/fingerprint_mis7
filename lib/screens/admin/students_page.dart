import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentsPage extends StatefulWidget {
  @override
  _StudentsPageState createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final CollectionReference studentsCollection =
      FirebaseFirestore.instance.collection('students');

  String _status = '';

  Future<void> _addOrEditStudent({DocumentSnapshot? student}) async {
    final TextEditingController studentIdController = TextEditingController(text: student?.get('studentId') ?? '');
    final TextEditingController firstNameController = TextEditingController(text: student?.get('firstName') ?? '');
    final TextEditingController middleNameController = TextEditingController(text: student?.get('middleName') ?? '');
    final TextEditingController lastNameController = TextEditingController(text: student?.get('lastName') ?? '');
    final TextEditingController departmentController = TextEditingController(text: student?.get('department') ?? '');
    final TextEditingController programController = TextEditingController(text: student?.get('program') ?? '');
    final TextEditingController emailController = TextEditingController(text: student?.get('email') ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(student == null ? 'Add Student' : 'Edit Student'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: studentIdController,
                  decoration: InputDecoration(labelText: 'Student ID'),
                ),
                TextField(
                  controller: firstNameController,
                  decoration: InputDecoration(labelText: 'First Name'),
                ),
                TextField(
                  controller: middleNameController,
                  decoration: InputDecoration(labelText: 'Middle Name (Optional)'),
                ),
                TextField(
                  controller: lastNameController,
                  decoration: InputDecoration(labelText: 'Last Name'),
                ),
                TextField(
                  controller: departmentController,
                  decoration: InputDecoration(labelText: 'Department'),
                ),
                TextField(
                  controller: programController,
                  decoration: InputDecoration(labelText: 'Program'),
                ),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final studentId = studentIdController.text.trim();
                final firstName = firstNameController.text.trim();
                final middleName = middleNameController.text.trim();
                final lastName = lastNameController.text.trim();
                final department = departmentController.text.trim();
                final program = programController.text.trim();
                final email = emailController.text.trim();

                if (studentId.isEmpty || firstName.isEmpty || lastName.isEmpty || department.isEmpty || program.isEmpty || email.isEmpty) {
                  setState(() {
                    _status = 'Please fill all required fields';
                  });
                  return;
                }

                try {
                  if (student == null) {
                    // Add new student
                    await studentsCollection.doc(studentId).set({
                      'studentId': studentId,
                      'firstName': firstName,
                      'middleName': middleName.isEmpty ? null : middleName,
                      'lastName': lastName,
                      'department': department,
                      'program': program,
                      'email': email,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    setState(() {
                      _status = 'Student added successfully';
                    });
                  } else {
                    // Update existing student
                    await studentsCollection.doc(studentId).update({
                      'firstName': firstName,
                      'middleName': middleName.isEmpty ? null : middleName,
                      'lastName': lastName,
                      'department': department,
                      'program': program,
                      'email': email,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    setState(() {
                      _status = 'Student updated successfully';
                    });
                  }
                  Navigator.of(context).pop();
                } catch (e) {
                  setState(() {
                    _status = 'Error: $e';
                  });
                }
              },
              child: Text(student == null ? 'Add' : 'Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteStudent(String studentId) async {
    try {
      await studentsCollection.doc(studentId).delete();
      setState(() {
        _status = 'Student deleted successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Error deleting student: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Students'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _addOrEditStudent(),
            tooltip: 'Add Student',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_status, style: TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: studentsCollection.orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                final students = snapshot.data?.docs ?? [];
                if (students.isEmpty) {
                  return Center(child: Text('No students found.'));
                }
                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return ListTile(
                      title: Text('${student.get('firstName')} ${student.get('lastName')}'),
                      subtitle: Text('ID: ${student.get('studentId')} - Dept: ${student.get('department')}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () => _addOrEditStudent(student: student),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () => _deleteStudent(student.get('studentId')),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
