import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';

class ReceiptViewer {
  /// Opens a modal that shows the receipt image (network).
  /// Pass only the filename (as stored in DB).
  static Future<void> openReceipt(
    BuildContext context, {
    required String imageFilename,
  }) async {
    final baseUrl = AppConfig.baseUrl;

    // ✅ Hardcode the rest of the path, as you requested
    final imageUrl = '${baseUrl}/uploads/$imageFilename';

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ReceiptDialog(imageUrl: imageUrl),
    );
  }
}

class _ReceiptDialog extends StatelessWidget {
  const _ReceiptDialog({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // ✅ Zoom + pan support
            InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stack) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'Failed to load receipt.\n$imageUrl',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(999),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
