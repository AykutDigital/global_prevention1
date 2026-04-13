import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/app_context_service.dart';

/// Navigation menu item data.
class NavItem {
  final IconData icon;
  final String title;
  final String routeName;
  final int globalIndex;

  const NavItem({
    required this.icon,
    required this.title,
    required this.routeName,
    required this.globalIndex,
  });
}

/// Sidebar menu used on desktop / drawer on mobile.
class SidebarMenu extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onLogout;
  final bool isDrawer;

  const SidebarMenu({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onLogout,
    this.isDrawer = false,
  });

  static const List<NavItem> items = [
    NavItem(icon: Icons.dashboard_rounded, title: 'Tableau de bord', routeName: 'dashboard', globalIndex: 2),
    NavItem(icon: Icons.people_rounded, title: 'Clients', routeName: 'clients', globalIndex: 0),
    NavItem(icon: Icons.build_circle_rounded, title: 'Interventions', routeName: 'interventions', globalIndex: 1),
    NavItem(icon: Icons.description_rounded, title: 'Rapports', routeName: 'reports', globalIndex: 3),
    NavItem(icon: Icons.notifications_active_rounded, title: 'Relances', routeName: 'relances', globalIndex: 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isDrawer ? null : 260,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        boxShadow: isDrawer
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Brand header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/global_prevention.png',
                      height: 36,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.security,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Global Prevention',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'GMAO v1.0',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isDrawer)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),

            // Branch Toggle Area
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                     ValueListenableBuilder<bool>(
                      valueListenable: AppContextService.instance.isVeriflammeActive,
                      builder: (context, isActive, _) {
                        return _BranchSwitch(
                          label: 'Veriflamme',
                          color: AppTheme.veriflammeRed,
                          icon: Icons.local_fire_department,
                          isActive: isActive,
                          onChanged: (_) => AppContextService.instance.toggleVeriflamme(),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                     ValueListenableBuilder<bool>(
                      valueListenable: AppContextService.instance.isSauvdefibActive,
                      builder: (context, isActive, _) {
                        return _BranchSwitch(
                          label: 'Sauvdefib',
                          color: AppTheme.sauvdefibGreen,
                          icon: Icons.medical_services,
                          isActive: isActive,
                          onChanged: (_) => AppContextService.instance.toggleSauvdefib(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Divider(color: Colors.white.withOpacity(0.1), height: 1),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // Menu items
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = items[index];
                    final isSelected = item.globalIndex == selectedIndex;
                    final showDivider = index == items.length - 1;

                    return Column(
                      children: [
                        if (showDivider) ...[
                          Divider(color: Colors.white.withOpacity(0.1), height: 24),
                        ],
                        _SidebarItem(
                          icon: item.icon,
                          title: item.title,
                          isSelected: isSelected,
                          onTap: () {
                            if (isDrawer && Navigator.of(context).canPop()) {
                              Navigator.pop(context);
                            }
                            onItemSelected(item.globalIndex);
                          },
                        ),
                      ],
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isSelected || _isHovered;
    final color = widget.isDestructive
        ? AppTheme.veriflammeRed
        : (isHighlighted ? Colors.white : Colors.white.withOpacity(0.6));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: widget.isSelected
              ? Colors.white.withOpacity(0.12)
              : (_isHovered ? Colors.white.withOpacity(0.06) : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(widget.icon, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: color,
                        fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (widget.isSelected)
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BranchSwitch extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool isActive;
  final ValueChanged<bool> onChanged;

  const _BranchSwitch({
    required this.label,
    required this.color,
    required this.icon,
    required this.isActive,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.12) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? color.withOpacity(0.3) : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: isActive ? color : Colors.white.withOpacity(0.3), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.7,
            child: Switch(
              value: isActive,
              onChanged: onChanged,
              activeColor: color,
              activeTrackColor: color.withOpacity(0.3),
              inactiveThumbColor: Colors.white.withOpacity(0.4),
              inactiveTrackColor: Colors.white.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
