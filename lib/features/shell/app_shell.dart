import 'package:flutter/material.dart';
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

  final _pages = const [
    UserDashboardScreen(),
    ExpenseHubScreen(),
    ApprovalHubScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab.clamp(0, _pages.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 900;

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
            child: Column(
              children: [
                _PremiumShellHeader(
                  isMobile: isMobile,
                  title: _titleForIndex(_index),
                ),
                Expanded(
                  child: Row(
                    children: [
                      if (!isMobile)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 0, 16),
                          child: _PremiumNavigationRail(
                            selectedIndex: _index,
                            onDestinationSelected: (i) =>
                                setState(() => _index = i),
                          ),
                        ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Container(
                            key: ValueKey(_index),
                            margin: EdgeInsets.fromLTRB(
                              isMobile ? 12 : 16,
                              8,
                              isMobile ? 12 : 16,
                              isMobile ? 12 : 16,
                            ),
                            child: _pages[_index],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.94),
                border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 18,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                backgroundColor: Colors.transparent,
                indicatorColor: const Color(0xFFE0ECFF),
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
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
              ),
            )
          : null,
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return "Dashboard";
      case 1:
        return "Expense";
      case 2:
        return "Approvals";
      default:
        return "SpendFlow";
    }
  }
}

class _PremiumShellHeader extends StatelessWidget {
  const _PremiumShellHeader({required this.isMobile, required this.title});

  final bool isMobile;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        isMobile ? 12 : 16,
        12,
        isMobile ? 12 : 16,
        8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.80)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset(
            "assets/spendflow_transparent_title.png",
            height: 42,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 14),
          if (!isMobile)
            Container(height: 34, width: 1, color: const Color(0xFFE2E8F0)),
          if (!isMobile) const SizedBox(width: 14),
          if (!isMobile)
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            )
          else
            const Spacer(),
          const ProfileMenu(),
        ],
      ),
    );
  }
}

class _PremiumNavigationRail extends StatelessWidget {
  const _PremiumNavigationRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        backgroundColor: Colors.transparent,
        useIndicator: true,
        indicatorColor: const Color(0xFFE0ECFF),
        selectedLabelTextStyle: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
        selectedIconTheme: const IconThemeData(
          color: Color(0xFF1D4ED8),
          size: 24,
        ),
        unselectedIconTheme: const IconThemeData(
          color: Color(0xFF64748B),
          size: 22,
        ),
        labelType: NavigationRailLabelType.all,
        groupAlignment: -0.75,
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
    );
  }
}
