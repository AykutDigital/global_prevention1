import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../services/supabase_service.dart';
import 'technician_form_screen.dart';

class TechniciansScreen extends StatefulWidget {
  const TechniciansScreen({super.key});

  @override
  State<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends State<TechniciansScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des techniciens'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TechnicianFormScreen()),
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(isMobile ? '' : 'Nouveau technicien'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Technician>>(
        stream: SupabaseService.instance.techniciansStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final allTechs = snapshot.data ?? [];
          final filteredTechs = allTechs.where((t) {
            final search = _searchQuery.toLowerCase();
            return t.nomComplet.toLowerCase().contains(search) || 
                   t.email.toLowerCase().contains(search);
          }).toList();

          return CustomScrollView(
            slivers: [
              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Rechercher par nom ou email...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.divider),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Tech List
              if (filteredTechs.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Aucun technicien trouvé')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tech = filteredTechs[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: tech.actif ? AppTheme.infoBlueLight : AppTheme.divider,
                              child: Icon(
                                tech.isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                                color: tech.actif ? AppTheme.infoBlue : AppTheme.secondaryText,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    tech.nomComplet,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!tech.actif) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Inactif', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(tech.email, maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (tech.telephone != null) Text(tech.telephone!, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => TechnicianFormScreen(technician: tech)),
                                );
                              },
                            ),
                          ),
                        );
                      },
                      childCount: filteredTechs.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
