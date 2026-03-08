import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/http/dio_client.dart';

class ChangePicturePage extends StatefulWidget {
  const ChangePicturePage({super.key});

  @override
  State<ChangePicturePage> createState() => _ChangePicturePageState();
}

class _ChangePicturePageState extends State<ChangePicturePage> {
  final Dio _dio = DioClient.dio;
  final ImagePicker _picker = ImagePicker();

  bool _loading = false;
  String? _error;

  File? _selectedFile;
  File? _compressedFile;
  ImageProvider? _previewImage;
  String? _currentProfilePicture;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserPicture();
  }

  Future<void> _loadCurrentUserPicture() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString("user");
    if (rawUser == null || rawUser.isEmpty) return;

    try {
      final user = jsonDecode(rawUser) as Map<String, dynamic>;
      final profilePicture = user["profilePicture"]?.toString();

      if (profilePicture != null && profilePicture.trim().isNotEmpty) {
        setState(() {
          _currentProfilePicture = profilePicture;
        });
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString("user");
    if (rawUser == null || rawUser.isEmpty) return null;

    try {
      return jsonDecode(rawUser) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<File> _compressToJpg(File input) async {
    final dir = await getTemporaryDirectory();
    final outPath = p.join(
      dir.path,
      "profile_${DateTime.now().millisecondsSinceEpoch}.jpg",
    );

    final bytes = await FlutterImageCompress.compressWithFile(
      input.path,
      format: CompressFormat.jpeg,
      quality: 75,
      minWidth: 1024,
      minHeight: 1024,
    );

    if (bytes == null) {
      throw Exception("Failed to compress image.");
    }

    final outFile = File(outPath);
    await outFile.writeAsBytes(bytes);
    return outFile;
  }

  Future<void> _pickImage() async {
    setState(() => _error = null);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text("Take Photo"),
                subtitle: const Text("Use your camera"),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Choose from Gallery"),
                subtitle: const Text("Pick an existing image"),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 100);
    if (picked == null) return;

    setState(() => _loading = true);

    try {
      final rawFile = File(picked.path);
      final compressed = await _compressToJpg(rawFile);

      setState(() {
        _selectedFile = rawFile;
        _compressedFile = compressed;
        _previewImage = FileImage(compressed);
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _upload() async {
    setState(() => _error = null);

    if (_compressedFile == null) {
      setState(() {
        _error = "Please select an image first.";
      });
      return;
    }

    final user = await _getCachedUser();
    final userId = (user?["id"] as num?)?.toInt();

    if (userId == null) {
      setState(() {
        _error = "No logged-in user found. Please login again.";
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          _compressedFile!.path,
          filename: p.basename(_compressedFile!.path),
        ),
      });

      final response = await _dio.post(
        "/api/users/$userId/upload-profile-picture",
        data: formData,
      );

      final data = response.data;
      final filename = data is Map<String, dynamic>
          ? data["filename"]?.toString()
          : null;

      if (filename == null || filename.trim().isEmpty) {
        throw Exception("Upload succeeded but no filename was returned.");
      }

      final prefs = await SharedPreferences.getInstance();
      final updatedUser = {...?user, "profilePicture": filename};
      await prefs.setString("user", jsonEncode(updatedUser));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Text("Profile picture updated successfully!"),
        ),
      );

      setState(() {
        _currentProfilePicture = filename;
        _previewImage = null;
        _selectedFile = null;
        _compressedFile = null;
      });

      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      String message = "Error uploading profile picture. Please try again.";
      final data = e.response?.data;

      if (data is Map<String, dynamic> && data["message"] != null) {
        message = data["message"].toString();
      } else if (data is String && data.trim().isNotEmpty) {
        message = data;
      } else if (e.message != null && e.message!.trim().isNotEmpty) {
        message = e.message!;
      }

      if (mounted) {
        setState(() => _error = message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst("Exception: ", "");
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  ImageProvider _buildDisplayImage() {
    if (_previewImage != null) return _previewImage!;

    if (_currentProfilePicture != null &&
        _currentProfilePicture!.trim().isNotEmpty) {
      return NetworkImage(
        "${AppConfig.baseUrl}/uploads/profilePictures/${_currentProfilePicture!}",
      );
    }

    return const AssetImage("assets/avatar_default.jpg");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FB),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEFF6FF),
                  Color(0xFFF8FAFC),
                  Color(0xFFF3F7FB),
                ],
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1D4ED8),
                        Color(0xFF2563EB),
                        Color(0xFF14B8A6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          "Profile Settings",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Change Account Picture",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Upload a clean square photo for the best profile appearance.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x140F172A),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 62,
                        backgroundColor: const Color(0xFFE2E8F0),
                        backgroundImage: _buildDisplayImage(),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _selectedFile != null
                            ? p.basename(_selectedFile!.path)
                            : "No new image selected",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _pickImage,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text("Choose Image"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _upload,
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: Text(_loading ? "Uploading..." : "Upload"),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text("Cancel"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.28),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
