import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart';

class InvigilatorSettingsPage extends StatefulWidget {
  @override
  _InvigilatorSettingsPageState createState() => _InvigilatorSettingsPageState();
}

class _InvigilatorSettingsPageState extends State<InvigilatorSettingsPage> {
  bool _notificationsEnabled = true;
  bool _darkThemeEnabled = false;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('Enable Notifications'),
            value: _notificationsEnabled,
            onChanged: (bool value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          SwitchListTile(
            title: Text('Enable Dark Theme'),
            value: _darkThemeEnabled,
            onChanged: (bool value) {
              setState(() {
                _darkThemeEnabled = value;
              });
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.redAccent),
            title: Text('Logout', style: TextStyle(color: Colors.redAccent)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
