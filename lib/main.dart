import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // ✅ initialize Firebase before app starts
  runApp(const ProviderScope(child: ExpenseManagementApp()));
}

class ExpenseManagementApp extends StatelessWidget {
  const ExpenseManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "ExpenseManagement",
      initialRoute: AppRoutes.login,
      onGenerateRoute: onGenerateRoute,
    );
  }
}
