import 'package:flutter/material.dart';

class ChangePicturePage extends StatelessWidget {
  const ChangePicturePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Change Account Picture")),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "Placeholder.\n\nNext we will:\n"
          "1) pick image (camera/gallery)\n"
          "2) compress (mobile)\n"
          "3) upload multipart\n"
          "4) update cached user + refresh header avatar",
        ),
      ),
    );
  }
}
