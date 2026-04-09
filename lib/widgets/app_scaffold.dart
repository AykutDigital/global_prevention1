import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'responsive_layout.dart';
import 'sidebar_menu.dart';
import '../screens/login_screen.dart';

/// Shell layout: sidebar (desktop) or drawer (mobile) + content area.
class AppScaffold extends StatefulWidget {
  final int selectedIndex;
  final Widget body;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.selectedIndex,
    required this.body,
    required this.title,
    this.actions,
    this.floatingActionButton,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _navigateTo(int index) {
    if (index == widget.selectedIndex) return;

    String route;
    switch (index) {
      case 0:
        route = '/clients';
        break;
      case 1:
        route = '/interventions';
        break;
      case 2:
        route = '/dashboard';
        break;
      case 3:
        route = '/reports';
        break;
      case 4:
        route = '/relances';
        break;
      case 5:
        route = '/admin';
        break;
      default:
        route = '/dashboard';
    }

    Navigator.pushReplacementNamed(context, route);
  }

  void _onBottomNavTap(int index) {
    _navigateTo(index);
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.title),
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          if (widget.actions != null) ...widget.actions!,
          // Menu Profil commun (Admin & Déconnexion)
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'admin') _navigateTo(5);
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'admin',
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings_rounded, size: 20, color: AppTheme.primaryText),
                    SizedBox(width: 12),
                    Text('Administration'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 20, color: AppTheme.veriflammeRed),
                    SizedBox(width: 12),
                    Text('Déconnexion', style: TextStyle(color: AppTheme.veriflammeRed)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Theme.of(context).dividerTheme.color,
            height: 1,
          ),
        ),
      ),
      drawer: isMobile
          ? SidebarMenu(
              selectedIndex: widget.selectedIndex,
              onItemSelected: (index) {
                Navigator.pop(context); // Close drawer
                _navigateTo(index);
              },
              onLogout: _logout,
              isDrawer: true,
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            SidebarMenu(
              selectedIndex: widget.selectedIndex,
              onItemSelected: _navigateTo,
              onLogout: _logout,
            ),
          Expanded(child: widget.body),
        ],
      ),
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: widget.selectedIndex > 4 ? 2 : widget.selectedIndex, // Si admin, on reset visuellement sur home (index 2)
              onTap: _onBottomNavTap,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.primary,
              unselectedItemColor: AppTheme.secondaryText,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Clients'),
                BottomNavigationBarItem(icon: Icon(Icons.build_circle_rounded), label: 'Missions'),
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Accueil'),
                BottomNavigationBarItem(icon: Icon(Icons.description_rounded), label: 'Rapports'),
                BottomNavigationBarItem(icon: Icon(Icons.notifications_active_rounded), label: 'Relances'),
              ],
            )
          : null,
      floatingActionButton: widget.floatingActionButton,
    );
  }
}

