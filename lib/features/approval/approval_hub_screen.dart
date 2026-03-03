import 'package:flutter/material.dart';
import 'approval_history_screen.dart';
import 'pending_approvals_screen.dart';
// TODO next: approval_history_screen.dart

class ApprovalHubScreen extends StatelessWidget {
  const ApprovalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: const [
          TabBar(
            tabs: [
              Tab(icon: Icon(Icons.hourglass_top), text: "Pending"),
              Tab(icon: Icon(Icons.history), text: "History"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [PendingApprovalsScreen(), ApprovalHistoryScreen()],
            ),
          ),
        ],
      ),
    );
  }
}
