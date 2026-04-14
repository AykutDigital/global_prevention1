import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/responsive_layout.dart';
import 'client_detail_screen.dart';
import 'client_form_screen.dart';
import '../services/supabase_service.dart';
import '../services/app_context_service.dart';
import '../repositories/client_repository.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _searchQuery = '';
  String _brancheFilter = 'Toutes'; // Toutes, Veriflamme, Sauvdefib
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    return AppScaffold(
      selectedIndex: 0,
      title: 'Clients',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientFormScreen()),
              );
              if (result == true) {
                // Not strictly necessary with StreamBuilder, but good for local feeling
                setState(() {});
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text(isMobile ? '' : 'Nouveau client'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20,
                vertical: 10,
              ),
            ),
          ),
        ),
      ],
      body: ValueListenableBuilder<bool>(
        valueListenable: AppContextService.instance.isVeriflammeActive,
        builder: (context, vfActive, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: AppContextService.instance.isSauvdefibActive,
            builder: (context, sdActive, _) {
              return StreamBuilder<List<Client>>(
                stream: ClientRepository.instance.clientsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  }

                  final allClients = snapshot.data ?? [];
                  // Pass the global filters to the local filtering logic
                  final clients = _filterClients(allClients, vfActive, sdActive);

                      return CustomScrollView(
                        slivers: [
                          // Filter Header
                          SliverToBoxAdapter(
                            child: Container(
                              padding: EdgeInsets.all(isMobile ? 12 : 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(bottom: BorderSide(color: AppTheme.divider)),
                              ),
                              child: isMobile
                                  ? Column(
                                      children: [
                                        _buildSearchField(),
                                        const SizedBox(height: 12),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: _buildBranchFilter(),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(flex: 2, child: _buildSearchField()),
                                        const SizedBox(width: 16),
                                        _buildBranchFilter(),
                                        const SizedBox(width: 16),
                                        _buildResultCount(clients.length),
                                      ],
                                    ),
                            ),
                          ),

                          // Client List
                          if (clients.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _buildEmptyState(),
                            )
                          else
                            SliverPadding(
                              padding: EdgeInsets.all(isMobile ? 12 : 20),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _buildClientCard(clients[index], isMobile),
                                  childCount: clients.length,
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
      ),
    );
  }

  List<Client> _filterClients(List<Client> allClients, bool vfActive, bool sdActive) {
    return allClients.where((c) {
      // Global Branch filter
      final matchesGlobalVF = vfActive && c.isVeriflamme;
      final matchesGlobalSD = sdActive && c.isSauvdefib;
      
      // If none of the global branches match, we exclude the client
      if (!matchesGlobalVF && !matchesGlobalSD) return false;

      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          c.raisonSociale.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.codeClient.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.ville.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.contactEmail.toLowerCase().contains(_searchQuery.toLowerCase());

      // Branch filter
      final matchesBranche = _branchFilter == 'Toutes' ||
          (_branchFilter == 'Veriflamme' && c.isVeriflamme) ||
          (_branchFilter == 'Sauvdefib' && c.isSauvdefib);

      return matchesSearch && matchesBranche;
    }).toList();
  }

  // Renommé pour cohérence avec le reste du code
  String get _branchFilter => _brancheFilter;

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: 'Rechercher par code, nom, ville, email...',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: AppTheme.background,
      ),
    );
  }

  Widget _buildBranchFilter() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'Toutes', label: Text('Toutes')),
        ButtonSegment(
          value: 'Veriflamme',
          icon: Icon(Icons.local_fire_department, size: 16),
          label: Text('VF'),
        ),
        ButtonSegment(
          value: 'Sauvdefib',
          icon: Icon(Icons.medical_services, size: 16),
          label: Text('SD'),
        ),
      ],
      selected: {_brancheFilter},
      onSelectionChanged: (v) => setState(() => _brancheFilter = v.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildResultCount(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count client${count > 1 ? 's' : ''}',
        style: TextStyle(
          color: AppTheme.secondaryText,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildClientCard(Client client, bool isMobile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientDetailScreen(client: client),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          child: isMobile ? _buildMobileCard(client) : _buildDesktopCard(client),
        ),
      ),
    );
  }

  Widget _buildMobileCard(Client client) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                client.raisonSociale,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _buildBranchBadges(client),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.secondaryText),
              onPressed: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => ClientFormScreen(clientToEdit: client))
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          client.codeClient,
          style: TextStyle(
            color: AppTheme.infoBlue,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 14, color: AppTheme.secondaryText),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${client.ville} (${client.codePostal})',
                style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.person_outline, size: 14, color: AppTheme.secondaryText),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                client.contactNom,
                style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopCard(Client client) {
    return Row(
      children: [
        // Code client
        SizedBox(
          width: 140,
          child: Text(
            client.codeClient,
            style: TextStyle(
              color: AppTheme.infoBlue,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Raison sociale + type
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.raisonSociale,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                client.typeClient.label,
                style: TextStyle(color: AppTheme.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ),
        // Location
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: AppTheme.secondaryText),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${client.ville} (${client.codePostal})',
                  style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Contact
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: AppTheme.secondaryText),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  client.contactNom,
                  style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Badges
        SizedBox(
          width: 80,
          child: _buildBranchBadges(client),
        ),
        // Actions
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: AppTheme.secondaryText, size: 20),
          onPressed: () => Navigator.push(
            context, 
            MaterialPageRoute(builder: (_) => ClientFormScreen(clientToEdit: client))
          ),
          tooltip: 'Modifier',
        ),
        const Icon(Icons.chevron_right_rounded, color: AppTheme.divider),
      ],
    );
  }

  Widget _buildBranchBadges(Client client) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (client.isVeriflamme)
          _badge('VF', AppTheme.veriflammeRed),
        if (client.isVeriflamme && client.isSauvdefib)
          const SizedBox(width: 6),
        if (client.isSauvdefib)
          _badge('SD', AppTheme.sauvdefibGreen),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: AppTheme.tertiaryText),
          const SizedBox(height: 16),
          Text(
            'Aucun client trouvé',
            style: TextStyle(
              color: AppTheme.secondaryText,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez de modifier vos filtres de recherche.',
            style: TextStyle(color: AppTheme.tertiaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
