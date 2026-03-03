import 'package:flutter/material.dart';

import '../approval/approvals_screen.dart';
import '../dashboard/user_dashboard_screen.dart';
import '../expense/expenseHubScreen.dart';
import '../profile/profile_menu.dart';
import '../approval/approval_hub_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index;

  // ✅ Dashboard is first (landing page)
  final _pages = const [
    UserDashboardScreen(),
    ExpenseHubScreen(),
    ApprovalHubScreen(),
  ];

  final _titles = const ["Dashboard", "Expense", "Approvals"];

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab.clamp(0, _pages.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          "assets/spendflow_transparent_title.png",
          height: 42,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        actions: const [
          Padding(padding: EdgeInsets.only(right: 8), child: ProfileMenu()),
        ],
      ),
      body: Row(
        children: [
          if (!isMobile)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text("Dashboard"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.request_quote_outlined),
                  selectedIcon: Icon(Icons.request_quote),
                  label: Text("Expense"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.approval_outlined),
                  selectedIcon: Icon(Icons.approval),
                  label: Text("Approvals"),
                ),
              ],
            ),
          Expanded(child: _pages[_index]),
        ],
      ),
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: "Dashboard",
                ),
                NavigationDestination(
                  icon: Icon(Icons.request_quote_outlined),
                  selectedIcon: Icon(Icons.request_quote),
                  label: "Expense",
                ),
                NavigationDestination(
                  icon: Icon(Icons.approval_outlined),
                  selectedIcon: Icon(Icons.approval),
                  label: "Approvals",
                ),
              ],
            )
          : null,
    );
  }
}
