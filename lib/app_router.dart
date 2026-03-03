import 'package:flutter/material.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/mfa_screen.dart';
import 'features/auth/models/auth_models.dart';
import 'features/shell/app_shell.dart';
import 'features/expense/apply_expense_screen.dart';
import 'features/approval/approvals_screen.dart';
import 'features/profile/change_password_screen.dart';
import 'features/profile/change_picture_screen.dart';
import 'features/dashboard/user_dashboard_screen.dart';

class AppRoutes {
  static const login = "/login";
  static const mfa = "/mfa";
  static const dashboard = "/dashboard";

  // Shell + pages
  static const shell = "/shell";
  static const applyExpense = "/apply-expense";
  static const approvals = "/approvals";

  // Profile actions
  static const changePassword = "/profile/change-password";
  static const changePicture = "/profile/change-picture";
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.login:
      return MaterialPageRoute(builder: (_) => const LoginScreen());

    case AppRoutes.mfa:
      final args = settings.arguments;
      if (args is! MfaChallenge) {
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text("Missing MFA args. Login again.")),
          ),
        );
      }
      return MaterialPageRoute(builder: (_) => MfaScreen(challenge: args));

    case AppRoutes.shell:
      final tab = (settings.arguments is int) ? settings.arguments as int : 0;
      return MaterialPageRoute(builder: (_) => AppShell(initialTab: tab));

    // ✅ These should NOT return the page directly.
    // ✅ They should return the shell with the correct tab.
    case AppRoutes.dashboard:
      return MaterialPageRoute(builder: (_) => const AppShell(initialTab: 0));

    case AppRoutes.applyExpense:
      return MaterialPageRoute(builder: (_) => const AppShell(initialTab: 1));

    case AppRoutes.approvals:
      return MaterialPageRoute(builder: (_) => const AppShell(initialTab: 2));

    case AppRoutes.changePassword:
      return MaterialPageRoute(builder: (_) => const ChangePasswordPage());

    case AppRoutes.changePicture:
      return MaterialPageRoute(builder: (_) => const ChangePicturePage());

    default:
      return MaterialPageRoute(
        builder: (_) =>
            const Scaffold(body: Center(child: Text("Route not found"))),
      );
  }
}
