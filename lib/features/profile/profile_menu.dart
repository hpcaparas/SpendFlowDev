import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_router.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/secure_storage.dart';

class ProfileMenu extends StatefulWidget {
  const ProfileMenu({super.key});

  @override
  State<ProfileMenu> createState() => _ProfileMenuState();
}

class _ProfileMenuState extends State<ProfileMenu> {
  String _name = "User";
  String? _profilePicture;
  int _avatarVersion = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("user");
    if (raw == null) return;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;

      setState(() {
        _name = (json["name"] ?? "User").toString();
        _profilePicture = json["profilePicture"]?.toString();
        _avatarVersion = DateTime.now().millisecondsSinceEpoch;
      });
    } catch (_) {
      // ignore bad cache
    }
  }

  ImageProvider _avatarProvider() {
    if (_profilePicture != null && _profilePicture!.trim().isNotEmpty) {
      return NetworkImage(
        "${AppConfig.baseUrl}/uploads/profilePictures/$_profilePicture?v=$_avatarVersion",
      );
    }
    return const AssetImage("assets/avatar_default.jpg");
  }

  Future<void> _openChangePicture() async {
    await Navigator.of(context).pushNamed(AppRoutes.changePicture);
    await _loadUser(); // refresh avatar after returning
  }

  Future<void> _openChangePassword() async {
    await Navigator.of(context).pushNamed(AppRoutes.changePassword);
    await _loadUser();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await SecureStorage.clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("user");
    await prefs.remove("userId");

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: "Profile",
      onSelected: (value) async {
        if (value == "picture") {
          await _openChangePicture();
        } else if (value == "password") {
          await _openChangePassword();
        } else if (value == "logout") {
          await _logout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          value: "header",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome,", style: Theme.of(context).textTheme.labelMedium),
              Text(_name, style: Theme.of(context).textTheme.titleMedium),
              const Divider(),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: "picture",
          child: ListTile(
            leading: Icon(Icons.image_outlined),
            title: Text("Change Account Picture"),
            dense: true,
          ),
        ),
        const PopupMenuItem<String>(
          value: "password",
          child: ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text("Change Password"),
            dense: true,
          ),
        ),
        const PopupMenuItem<String>(
          value: "logout",
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text("Logout"),
            dense: true,
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFE2E8F0),
          backgroundImage: _avatarProvider(),
        ),
      ),
    );
  }
}
