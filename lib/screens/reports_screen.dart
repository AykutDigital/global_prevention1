import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../services/app_context_service.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import '../repositories/client_repository.dart';
import 'report_preview_screen.dart';
import 'client_reports_detail_screen.dart';

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

  // Logique de traitement des données pour regrouper par client
  Map<Client, Map<Branche, List<Rapport>>> _processReports(
    List<Rapport> allRapports,
    List<Client> allClients,
    List<Intervention> allInterventions,
    bool vfActive,
    bool sdActive,
  ) {
    // 1. Filtrage initial des rapports
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

    // 3. Groupage par client
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
                stream: ClientRepository.instance.clientsStream,
                builder: (context, clientSnapshot) {
                  return StreamBuilder<List<Intervention>>(
                    stream: SupabaseService.instance.interventionsStream,
                    initialData: const [],
                    builder: (context, interventionSnapshot) {
                      return StreamBuilder<List<Rapport>>(
                        stream: SupabaseService.instance.rapportsStream,
                        initialData: const [],
                        builder: (context, rapportSnapshot) {
                          if (!clientSnapshot.hasData && clientSnapshot.connectionState == ConnectionState.waiting) {
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
                                        return _buildClientGroupCard(client, branches, allInterventions, isMobile);
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un client...',
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
    final totalCount = vfRapports.length + sdRapports.length;

    // Find latest report date across all branches
    DateTime? latestDate;
    if (vfRapports.isNotEmpty) latestDate = vfRapports.first.dateCreation;
    if (sdRapports.isNotEmpty) {
      final sdLatest = sdRapports.first.dateCreation;
      if (latestDate == null || sdLatest.isAfter(latestDate)) {
        latestDate = sdLatest;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.divider),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (_) => ClientReportsDetailScreen(
              client: client,
              branches: branches,
              allInterventions: allInterventions,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.infoBlue.withOpacity(0.1),
                radius: 24,
                child: Text(
                  client.raisonSociale[0].toUpperCase(), 
                  style: TextStyle(color: AppTheme.infoBlue, fontWeight: FontWeight.bold, fontSize: 18)
                ),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${client.codeClient} • ${client.ville}', 
                          style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                        ),
                        if (latestDate != null) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('•', style: TextStyle(color: AppTheme.tertiaryText, fontSize: 13)),
                              const SizedBox(width: 8),
                              Icon(Icons.history_rounded, size: 12, color: AppTheme.primary.withOpacity(0.6)),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(latestDate),
                                style: TextStyle(color: AppTheme.primary.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$totalCount rapport${totalCount > 1 ? 's' : ''}',
                      style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.tertiaryText, size: 20),
                ],
              ),
            ],
          ),
        ),
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
