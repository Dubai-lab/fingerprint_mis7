import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfessorsPage extends StatefulWidget {
  @override
  _ProfessorsPageState createState() => _ProfessorsPageState();
}

class _ProfessorsPageState extends State<ProfessorsPage> {
  final CollectionReference instructorsCollection =
      FirebaseFirestore.instance.collection('instructors');

  String _status = '';

  Future<void> _addOrEditProfessor({DocumentSnapshot? professor}) async {
    final TextEditingController userIdController = TextEditingController(text: professor?.get('userId') ?? '');
    final TextEditingController firstNameController = TextEditingController(text: professor?.get('firstName') ?? '');
    final TextEditingController middleNameController = TextEditingController(text: professor?.get('middleName') ?? '');
    final TextEditingController lastNameController = TextEditingController(text: professor?.get('lastName') ?? '');
    final TextEditingController emailController = TextEditingController(text: professor?.get('email') ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(professor == null ? 'Add Professor' : 'Edit Professor'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: userIdController,
                  decoration: InputDecoration(labelText: 'User ID'),
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
                final userId = userIdController.text.trim();
                final firstName = firstNameController.text.trim();
                final middleName = middleNameController.text.trim();
                final lastName = lastNameController.text.trim();
                final email = emailController.text.trim();

                if (userId.isEmpty || firstName.isEmpty || lastName.isEmpty || email.isEmpty) {
                  setState(() {
                    _status = 'Please fill all required fields';
                  });
                  return;
                }

                try {
                  if (professor == null) {
                    // Add new professor
                    await instructorsCollection.doc(userId).set({
                      'userId': userId,
                      'firstName': firstName,
                      'middleName': middleName.isEmpty ? null : middleName,
                      'lastName': lastName,
                      'email': email,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    setState(() {
                      _status = 'Professor added successfully';
                    });
                  } else {
                    // Update existing professor
                    await instructorsCollection.doc(userId).update({
                      'firstName': firstName,
                      'middleName': middleName.isEmpty ? null : middleName,
                      'lastName': lastName,
                      'email': email,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    setState(() {
                      _status = 'Professor updated successfully';
                    });
                  }
                  Navigator.of(context).pop();
                } catch (e) {
                  setState(() {
                    _status = 'Error: $e';
                  });
                }
              },
              child: Text(professor == null ? 'Add' : 'Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProfessor(String userId) async {
    try {
      await instructorsCollection.doc(userId).delete();
      setState(() {
        _status = 'Professor deleted successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Error deleting professor: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Professors'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _addOrEditProfessor(),
            tooltip: 'Add Professor',
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
              stream: instructorsCollection.orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                final professors = snapshot.data?.docs ?? [];
                if (professors.isEmpty) {
                  return Center(child: Text('No professors found.'));
                }
                return ListView.builder(
                  itemCount: professors.length,
                  itemBuilder: (context, index) {
                    final professor = professors[index];
                    return ListTile(
                      title: Text('${professor.get('firstName')} ${professor.get('lastName')}'),
                      subtitle: Text('ID: ${professor.get('userId')}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () => _addOrEditProfessor(professor: professor),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () => _deleteProfessor(professor.get('userId')),
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
