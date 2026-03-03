import 'package:flutter/material.dart';

import '../expense/apply_expense_screen.dart';
// TODO: create this next
import '../expense/my_expense_applications_screen.dart';

class ExpenseHubScreen extends StatelessWidget {
  const ExpenseHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // ✅ keeps this inside the Expense tab, not a separate route
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.add_card), text: "New Request"),
              Tab(icon: Icon(Icons.list_alt), text: "My Applications"),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [ApplyExpenseScreen(), MyExpenseApplicationsScreen()],
            ),
          ),
        ],
      ),
    );
  }
}
