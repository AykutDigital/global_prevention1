import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../services/app_context_service.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import 'report_preview_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _sortAscending = false; // Par défaut : les plus récents en haut (descending)
  Conformite? _conformiteFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Logique de traitement des données
  Map<Client, Map<Branche, List<Rapport>>> _processReports(
    List<Rapport> allRapports,
    List<Client> allClients,
    List<Intervention> allInterventions,
    bool vfActive,
    bool sdActive,
  ) {
    // 1. Filtrage initial
    final filtered = allRapports.where((r) {
      // Filtre de Branche Globale
      final matchesGlobalVF = vfActive && r.branche == Branche.veriflamme;
      final matchesGlobalSD = sdActive && r.branche == Branche.sauvdefib;
      if (!matchesGlobalVF && !matchesGlobalSD) return false;

      // Filtre de Conformité
      if (_conformiteFilter != null && r.conformite != _conformiteFilter) return false;

      // Filtre de Recherche (Numéro ou Client)
      if (_searchQuery.isNotEmpty) {
        final intervention = allInterventions.firstWhere((i) => i.interventionId == r.interventionId, orElse: () => allInterventions.first);
        final client = allClients.firstWhere((c) => c.clientId == intervention.clientId, orElse: () => allClients.first);
        
        final matchesNum = r.numeroRapport.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesClient = client.raisonSociale.toLowerCase().contains(_searchQuery.toLowerCase());
        if (!matchesNum && !matchesClient) return false;
      }

      return true;
    }).toList();

    // 2. Tri par date (ancienneté ou récent)
    filtered.sort((a, b) => _sortAscending 
        ? a.dateCreation.compareTo(b.dateCreation) 
        : b.dateCreation.compareTo(a.dateCreation));

    // 3. Groupage
    final Map<Client, Map<Branche, List<Rapport>>> grouped = {};

    for (var rapport in filtered) {
      final intervention = allInterventions.firstWhere((i) => i.interventionId == rapport.interventionId, orElse: () => allInterventions.first);
      final client = allClients.firstWhere((c) => c.clientId == intervention.clientId, orElse: () => allClients.first);

      if (!grouped.containsKey(client)) {
        grouped[client] = {Branche.veriflamme: [], Branche.sauvdefib: []};
      }
      grouped[client]![rapport.branche]!.add(rapport);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    return AppScaffold(
      selectedIndex: 3,
      title: 'Rapports',
      body: ValueListenableBuilder<bool>(
        valueListenable: AppContextService.instance.isVeriflammeActive,
        builder: (context, vfActive, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: AppContextService.instance.isSauvdefibActive,
            builder: (context, sdActive, _) {
              return StreamBuilder<List<Client>>(
                stream: SupabaseService.instance.clientsStream,
                builder: (context, clientSnapshot) {
                  return StreamBuilder<List<Intervention>>(
                    stream: SupabaseService.instance.interventionsStream,
                    builder: (context, interventionSnapshot) {
                      return StreamBuilder<List<Rapport>>(
                        stream: SupabaseService.instance.rapportsStream,
                        builder: (context, rapportSnapshot) {
                          if (rapportSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          final allRapports = rapportSnapshot.data ?? [];
                          final allClients = clientSnapshot.data ?? [];
                          final allInterventions = interventionSnapshot.data ?? [];

                          final groupedData = _processReports(
                            allRapports, 
                            allClients, 
                            allInterventions, 
                            vfActive, 
                            sdActive
                          );

                          return CustomScrollView(
                            slivers: [
                              // Header (Search, Sort, Filters)
                              SliverToBoxAdapter(
                                child: _buildHeader(isMobile),
                              ),

                              // Content Area
                              if (groupedData.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: _buildEmptyState(),
                                )
                              else
                                SliverPadding(
                                  padding: EdgeInsets.all(isMobile ? 12 : 20),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final client = groupedData.keys.elementAt(index);
                                        final branches = groupedData[client]!;
                                        final interventionsForClient = allInterventions.where((i) => i.clientId == client.clientId).toList();
                                        return _buildClientGroupCard(client, branches, interventionsForClient, isMobile);
                                      },
                                      childCount: groupedData.length,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Column(
        children: [
          // Row 1: Search & Sort
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un client ou un rapport...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          })) 
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _sortToggle(),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: Conformity Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Tous', _conformiteFilter == null, () => setState(() => _conformiteFilter = null)),
                const SizedBox(width: 8),
                _filterChip('Conformes', _conformiteFilter == Conformite.conforme, () => setState(() => _conformiteFilter = Conformite.conforme)),
                const SizedBox(width: 8),
                _filterChip('Non-conformes', _conformiteFilter == Conformite.nonConforme, () => setState(() => _conformiteFilter = Conformite.nonConforme)),
                const SizedBox(width: 8),
                _filterChip('Avec réserves', _conformiteFilter == Conformite.avecReserves, () => setState(() => _conformiteFilter = Conformite.avecReserves)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortToggle() {
    return InkWell(
      onTap: () => setState(() => _sortAscending = !_sortAscending),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.infoBlueLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.infoBlue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, 
                 color: AppTheme.infoBlue, size: 16),
            const SizedBox(width: 6),
            Text(
              _sortAscending ? 'Anciens' : 'Récents',
              style: TextStyle(color: AppTheme.infoBlue, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12, 
        color: isSelected ? Colors.white : AppTheme.secondaryText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selectedColor: AppTheme.infoBlue,
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildClientGroupCard(
    Client client, 
    Map<Branche, List<Rapport>> branches, 
    List<Intervention> allInterventions,
    bool isMobile
  ) {
    final vfRapports = branches[Branche.veriflamme]!;
    final sdRapports = branches[Branche.sauvdefib]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.infoBlue,
                  radius: 18,
                  child: Text(client.raisonSociale[0].toUpperCase(), 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.raisonSociale, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('${client.codeClient} • ${client.ville}', 
                          style: TextStyle(color: AppTheme.secondaryText, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.business_rounded, color: AppTheme.tertiaryText, size: 20),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Branch Sections
          if (vfRapports.isNotEmpty)
            _buildBranchSection(Branche.veriflamme, vfRapports, allInterventions, client, isMobile),
          
          if (vfRapports.isNotEmpty && sdRapports.isNotEmpty)
            const Divider(height: 1, indent: 16, endIndent: 16),

          if (sdRapports.isNotEmpty)
            _buildBranchSection(Branche.sauvdefib, sdRapports, allInterventions, client, isMobile),
        ],
      ),
    );
  }

  Widget _buildBranchSection(
    Branche branche, 
    List<Rapport> rapports, 
    List<Intervention> allInterventions,
    Client client,
    bool isMobile
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(branche.icon, color: branche.color, size: 18),
              const SizedBox(width: 8),
              Text(
                branche.label.toUpperCase(),
                style: TextStyle(color: branche.color, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1),
              ),
              const Spacer(),
              Text('${rapports.length} rapport(s)', style: TextStyle(color: AppTheme.tertiaryText, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          ...rapports.map((r) {
            final intervention = allInterventions.firstWhere((i) => i.interventionId == r.interventionId, orElse: () => allInterventions.first);
            return _buildSimpleRapportTile(r, intervention, client, isMobile);
          }),
        ],
      ),
    );
  }

  Widget _buildSimpleRapportTile(Rapport rapport, Intervention intervention, Client client, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rapport.numeroRapport, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(rapport.dateCreation)} • ${rapport.typeRapport == TypeIntervention.installation ? "Install." : "Maint."}',
                  style: TextStyle(color: AppTheme.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          _conformiteBadge(rapport.conformite),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.visibility_rounded, color: AppTheme.primary, size: 20),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportPreviewScreen(
              client: client,
              intervention: intervention,
              rapport: rapport,
            ))),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 64, color: AppTheme.tertiaryText),
          const SizedBox(height: 16),
          const Text('Aucun rapport ne correspond à vos filtres', style: TextStyle(color: AppTheme.secondaryText)),
          if (_searchQuery.isNotEmpty || _conformiteFilter != null)
            TextButton(
              onPressed: () => setState(() {
                _searchController.clear();
                _searchQuery = '';
                _conformiteFilter = null;
              }),
              child: const Text('Réinitialiser les filtres'),
            ),
        ],
      ),
    );
  }

  Widget _conformiteBadge(Conformite conformite) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: conformite.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        conformite.label,
        style: TextStyle(color: conformite.color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
