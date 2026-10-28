import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Displays an admin password prompt dialog requiring password '118022'
/// to transition from Staff to Admin role.
Future<bool> promptAdminPassword(BuildContext context) async {
  final controller = TextEditingController();
  bool obscure = true;
  String? errorMessage;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Admin Password (Dr. Jeswin)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter administrator password to unlock Admin mode.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter password',
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                  errorText: errorMessage,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: (val) {
                  if (val.trim() == '118022') {
                    Navigator.pop(ctx, true);
                  } else {
                    setDialogState(() => errorMessage = 'Incorrect password. Admin access denied.');
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (controller.text.trim() == '118022') {
                  Navigator.pop(ctx, true);
                } else {
                  setDialogState(() => errorMessage = 'Incorrect password. Admin access denied.');
                }
              },
              child: const Text('Unlock Admin'),
            ),
          ],
        );
      },
    ),
  );
  return result == true;
}
