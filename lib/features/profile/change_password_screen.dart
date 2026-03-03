import 'package:flutter/material.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _oldCtrl = TextEditingController();
  final _confirmOldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();

  @override
  void dispose() {
    _oldCtrl.dispose();
    _confirmOldCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_oldCtrl.text != _confirmOldCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Old password and confirm do not match.")),
      );
      return;
    }

    // Placeholder: later call backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Placeholder: change password API call later."),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Change Password")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _oldCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Old Password",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmOldCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Confirm Old Password",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "New Password",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _save, child: const Text("Save")),
        ],
      ),
    );
  }
}
