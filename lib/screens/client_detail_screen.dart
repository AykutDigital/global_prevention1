import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/responsive_layout.dart';
import '../services/supabase_service.dart';
import '../repositories/client_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'report_preview_screen.dart';
import '../services/pdf_service.dart';
import 'client_form_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final Client client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(client.raisonSociale),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientFormScreen(clientToEdit: client),
                ),
              );
              if (result == true && mounted) {
                // If the detail screen is still open after edit, 
                // we might need to refresh or pop if the ID changed (rare)
                // Since it's a stream, it might auto-update if we are watching the specific client
              }
            },
            tooltip: 'Modifier',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'supprimer') {
                _confirmDelete(context, client);
              } else {
                _showSnackbar('$value — en cours de développement');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'intervention', child: Text('Nouvelle intervention')),
              const PopupMenuItem(value: 'relance', child: Text('Envoyer relance')),
              const PopupMenuItem(value: 'archiver', child: Text('Archiver le client')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'supprimer', 
                child: Text('Supprimer définitivement', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: isMobile,
          tabs: const [
            Tab(text: 'Informations'),
            Tab(text: 'Interventions'),
            Tab(text: 'Rapports'),
            Tab(text: 'Relances'),
            Tab(text: 'Équipements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(client, isMobile),
          _buildInterventionsTab(client.clientId),
          _buildRapportsTab(client),
          _buildRelancesTab(client.clientId),
          _buildEquipmentTab(client.clientId),
        ],
      ),
      floatingActionButton: _tabController.index == 4 
        ? FloatingActionButton.extended(
            onPressed: () => _showAddEquipmentDialog(context, client.clientId),
            icon: const Icon(Icons.add_box_rounded),
            label: const Text('Équipement'),
            backgroundColor: AppTheme.primary,
          )
        : FloatingActionButton.extended(
            onPressed: () {
              Navigator.pushNamed(context, '/new-intervention');
            },
            icon: const Icon(Icons.add),
            label: const Text('Intervention'),
          ),
    );
  }

  Widget _buildInfoTab(Client client, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Card (General Info)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.infoBlueLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        client.codeClient,
                        style: const TextStyle(
                          color: AppTheme.infoBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (client.isVeriflamme) _branchChip('Veriflamme', AppTheme.veriflammeRed),
                    if (client.isVeriflamme && client.isSauvdefib) const SizedBox(width: 8),
                    if (client.isSauvdefib) _branchChip('Sauvdefib', AppTheme.sauvdefibGreen),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: client.actif ? AppTheme.sauvdefibGreenLight : AppTheme.divider,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        client.actif ? 'Actif' : 'Archivé',
                        style: TextStyle(
                          color: client.actif ? AppTheme.sauvdefibGreen : AppTheme.secondaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  client.raisonSociale,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  '${client.typeClient.label} • Créé le ${_formatDate(client.dateCreation)}',
                  style: const TextStyle(color: AppTheme.secondaryText, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Identité Juridique
          _infoSectionTitle('Identité Juridique'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _infoCard(Icons.badge_outlined, 'SIRET', client.siret ?? '—', isMobile ? double.infinity : 220),
              _infoCard(Icons.category_rounded, 'Code NAF', client.codeNaf ?? '—', isMobile ? double.infinity : 220),
              _infoCard(Icons.account_balance_rounded, 'TVA Intra', client.tvaIntra ?? '—', isMobile ? double.infinity : 220),
              _infoCard(Icons.work_rounded, 'Activité', client.activite ?? '—', isMobile ? double.infinity : 220),
              _infoCard(Icons.warning_rounded, 'Risques particuliers', client.risquesParticuliers ?? '—', isMobile ? double.infinity : 456),
            ],
          ),
          const SizedBox(height: 24),

          // 3. Contact & Facturation
          _infoSectionTitle('Contact & Facturation'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _infoCard(
                Icons.person_outline, 
                'Contact Principal', 
                '${client.contactNom}${client.contactPosition != null ? "\n(${client.contactPosition})" : ""}', 
                isMobile ? double.infinity : 340
              ),
              _infoCard(Icons.phone_outlined, 'Téléphone', client.contactTel, isMobile ? double.infinity : 340),
              _infoCard(Icons.email_outlined, 'Email Principal', client.contactEmail, isMobile ? double.infinity : 340),
              _infoCard(Icons.receipt_long_outlined, 'Email Facturation', client.billingEmail ?? client.contactEmail, isMobile ? double.infinity : 340),
              if (client.billingAddress != null)
                _infoCard(Icons.location_on_outlined, 'Adresse Facturation', client.billingAddress!, double.infinity),
            ],
          ),
          const SizedBox(height: 24),

          // 4. Site & Logistique
          _infoSectionTitle('Site & Logistique'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _infoCard(Icons.location_city_rounded, 'Adresse Intervention', '${client.adresse}\n${client.codePostal} ${client.ville}', double.infinity),
              _infoCard(Icons.layers_outlined, 'Étage / Porte', client.floor ?? '—', isMobile ? double.infinity : 220),
              _infoCard(Icons.lock_outline_rounded, 'Digicode', client.accessInstructions ?? '—', isMobile ? double.infinity : 456),
              _infoCard(Icons.gps_fixed_rounded, 'Coordonnées GPS', client.gpsCoordinates ?? '—', isMobile ? double.infinity : 220),
            ],
          ),
          const SizedBox(height: 24),

          // 5. Administration & Notes
          _infoSectionTitle('Administration'),
          const SizedBox(height: 12),
          _infoCard(Icons.timer_outlined, 'Délai de paiement', '${client.paymentTerms} jours', isMobile ? double.infinity : 220),
          
          if (client.noteInterne != null && client.noteInterne!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warningOrangeLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.warningOrange.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_rounded, color: AppTheme.warningOrange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Instructions & Notes internes',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warningOrange,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          client.noteInterne!,
                          style: const TextStyle(
                            color: AppTheme.primaryText,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _infoSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.secondaryText,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInterventionsTab(String clientId) {
    return StreamBuilder<List<Intervention>>(
      stream: SupabaseService.instance.interventionsForClientStream(clientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final interventions = snapshot.data ?? [];
        if (interventions.isEmpty) {
          return _buildPlaceholderTab(
            Icons.build_circle_rounded,
            'Aucune intervention',
            'Aucune intervention enregistrée pour ce client.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: interventions.length,
          itemBuilder: (context, index) {
            final i = interventions[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: i.branche.lightColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(i.branche.icon, color: i.branche.color, size: 22),
                ),
                title: Text(
                  '${i.typeIntervention == TypeIntervention.installation ? "Installation" : "Maintenance"} — ${i.branche.label}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${_formatDate(i.dateIntervention)} • ${i.periodicite.label} • ${i.technicienNom}',
                    style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: i.statut.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        i.statut.label,
                        style: TextStyle(
                          color: i.statut.color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                      tooltip: 'Supprimer',
                      onPressed: () => _confirmDeleteIntervention(context, i),
                    ),
                  ],
                ),
                onTap: () => _showSnackbar('Détail intervention — en cours de développement'),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRapportsTab(Client client) {
    return StreamBuilder<List<Intervention>>(
      stream: SupabaseService.instance.interventionsForClientStream(client.clientId),
      builder: (context, interventionSnapshot) {
        return StreamBuilder<List<Rapport>>(
          stream: SupabaseService.instance.rapportsStream,
          builder: (context, rapportSnapshot) {
            if (rapportSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allInterventions = interventionSnapshot.data ?? [];
            final interventionIds = allInterventions.map((i) => i.interventionId).toSet();
            final rapports = (rapportSnapshot.data ?? [])
                .where((r) => interventionIds.contains(r.interventionId))
                .toList();

            if (rapports.isEmpty) {
              return _buildPlaceholderTab(
                Icons.description_rounded,
                'Aucun rapport',
                'Les rapports associés à ce client seront affichés ici.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rapports.length,
              itemBuilder: (context, index) {
                final r = rapports[index];
                final intervention = allInterventions.firstWhere((i) => i.interventionId == r.interventionId);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Icon(Icons.picture_as_pdf_rounded, color: AppTheme.veriflammeRed),
                    title: Text(r.numeroRapport, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_formatDate(r.dateCreation)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_rounded, size: 20),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportPreviewScreen(
                            client: client,
                            intervention: intervention,
                            rapport: r,
                          ))),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, size: 20, color: AppTheme.infoBlue),
                          onPressed: () => PdfService.sendEmailLink(client.contactEmail, r.pdfUrl ?? '', r.numeroRapport),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                          tooltip: 'Supprimer',
                          onPressed: () => _confirmDeleteRapport(context, r, intervention),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRelancesTab(String clientId) {
    return StreamBuilder<List<Relance>>(
      stream: SupabaseService.instance.relancesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final relances = (snapshot.data ?? []).where((r) => r.clientId == clientId).toList();
        if (relances.isEmpty) {
          return _buildPlaceholderTab(
            Icons.notifications_active_rounded,
            'Aucune relance',
            'Aucune relance planifiée pour ce client.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: relances.length,
          itemBuilder: (context, index) {
            final r = relances[index];
            final jours = r.joursRestants;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: r.urgencyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    jours < 0 ? Icons.error_rounded : Icons.schedule_rounded,
                    color: r.urgencyColor,
                    size: 22,
                  ),
                ),
                title: Text(
                  '${r.typeMaintenance.label} — ${r.branche.label}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Échéance : ${_formatDate(r.dateEcheance)} • ${r.nbRelancesEnvoyees} relance(s)',
                    style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: r.urgencyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    jours < 0 ? 'Dépassé J+${-jours}' : 'J-$jours',
                    style: TextStyle(
                      color: r.urgencyColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEquipmentTab(String clientId) {
    return StreamBuilder<List<Equipment>>(
      stream: SupabaseService.instance.equipmentStream(clientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final equipment = snapshot.data ?? [];
        if (equipment.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPlaceholderTab(
                Icons.inventory_2_rounded,
                'Aucun équipement',
                'La liste des équipements installés sur site sera affichée ici.',
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddEquipmentDialog(context, clientId),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter le premier équipement'),
              ),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: equipment.length,
          itemBuilder: (context, index) {
            final e = equipment[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: e.branche == Branche.veriflamme ? AppTheme.veriflammeRed.withOpacity(0.1) : AppTheme.sauvdefibGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    e.type.toLowerCase().contains('extincteur') ? Icons.fire_extinguisher : Icons.medical_services,
                    color: e.branche == Branche.veriflamme ? AppTheme.veriflammeRed : AppTheme.sauvdefibGreen,
                    size: 20,
                  ),
                ),
                title: Text('${e.type} ${e.capacity ?? ""}'.trim(), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  [
                    if (e.brand != null && e.brand!.isNotEmpty) e.brand!,
                    if (e.niveau != null && e.niveau!.isNotEmpty) 'Niv. ${e.niveau}',
                    if (e.location != null && e.location!.isNotEmpty) e.location!,
                  ].join(' • '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      color: AppTheme.primary,
                      tooltip: 'Modifier',
                      onPressed: () => _showAddEquipmentDialog(context, clientId, equipmentToEdit: e),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: Colors.red,
                      tooltip: 'Supprimer',
                      onPressed: () => _confirmDeleteEquipment(context, e),
                    ),
                  ],
                ),
                onTap: () => _showAddEquipmentDialog(context, clientId, equipmentToEdit: e),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteEquipment(BuildContext context, Equipment e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'équipement'),
        content: Text('Supprimer "${e.type} ${e.capacity ?? ""}" ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.instance.deleteEquipment(e.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Équipement supprimé'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddEquipmentDialog(BuildContext context, String clientId, {Equipment? equipmentToEdit}) {
    showDialog(
      context: context,
      builder: (context) => _EquipmentFormDialog(clientId: clientId, equipmentToEdit: equipmentToEdit),
    );
  }

  Widget _buildPlaceholderTab(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppTheme.tertiaryText),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.secondaryText, fontSize: 16)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: AppTheme.tertiaryText, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _branchChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label == 'Veriflamme' ? Icons.local_fire_department : Icons.medical_services,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value, double width) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.secondaryText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.tertiaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _confirmDelete(BuildContext context, Client client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le client ?'),
        content: Text('Êtes-vous sûr de vouloir supprimer ${client.raisonSociale} ?\n\nCette action supprimera également tous ses rapports et équipements liés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              try {
                await ClientRepository.instance.deleteClient(client.clientId);
                if (context.mounted) {
                  Navigator.pop(context); // Go back to list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Client supprimé'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                if (context.mounted) _showSnackbar('Erreur lors de la suppression: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SUPPRIMER'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteIntervention(BuildContext context, Intervention intervention) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
        title: const Text('Supprimer l\'intervention ?'),
        content: const Text(
          'Cette action supprimera définitivement l\'intervention et le rapport associé. Cette opération est irréversible.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULER')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('SUPPRIMER'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final rapport = await SupabaseService.instance.getRapportByInterventionId(intervention.interventionId);
        if (rapport != null) {
          await SupabaseService.instance.deleteRapport(rapport.rapportId);
        }
        await SupabaseService.instance.deleteIntervention(intervention.interventionId);
        if (mounted) _showSnackbar('Intervention supprimée.');
      } catch (e) {
        if (mounted) _showSnackbar('Erreur : $e');
      }
    }
  }

  Future<void> _confirmDeleteRapport(BuildContext context, Rapport rapport, Intervention intervention) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
        title: const Text('Supprimer le rapport ?'),
        content: Text(
          'Supprimer uniquement le rapport "${rapport.numeroRapport}" ou aussi l\'intervention associée ?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULER')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Rapport seul', style: TextStyle(color: Colors.orange)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Rapport + Intervention'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await SupabaseService.instance.deleteRapport(rapport.rapportId);
        await SupabaseService.instance.deleteIntervention(intervention.interventionId);
        if (mounted) _showSnackbar('Rapport et intervention supprimés.');
      } catch (e) {
        if (mounted) _showSnackbar('Erreur : $e');
      }
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }
}

class _EquipmentFormDialog extends StatefulWidget {
  final String clientId;
  final Equipment? equipmentToEdit;

  const _EquipmentFormDialog({required this.clientId, this.equipmentToEdit});

  @override
  State<_EquipmentFormDialog> createState() => _EquipmentFormDialogState();
}

class _EquipmentFormDialogState extends State<_EquipmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _typeController;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _locationController;
  late TextEditingController _levelController;
  late TextEditingController _yearController;
  late TextEditingController _capacityController;
  late Branche _selectedBranche;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.equipmentToEdit;
    _typeController = TextEditingController(text: e?.type);
    _brandController = TextEditingController(text: e?.brand);
    _modelController = TextEditingController(text: e?.model);
    _locationController = TextEditingController(text: e?.location);
    _levelController = TextEditingController(text: e?.niveau);
    _yearController = TextEditingController(text: e?.manufactureYear?.toString());
    _capacityController = TextEditingController(text: e?.capacity);
    _selectedBranche = e?.branche ?? Branche.veriflamme;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.equipmentToEdit != null;

    return AlertDialog(
      title: Text(isEdit ? 'Modifier l\'équipement' : 'Ajouter un équipement'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Branche>(
                value: _selectedBranche,
                decoration: const InputDecoration(labelText: 'Branche', prefixIcon: Icon(Icons.business_rounded)),
                items: Branche.values.map((b) => DropdownMenuItem(value: b, child: Text(b.label))).toList(),
                onChanged: (v) => setState(() => _selectedBranche = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(labelText: 'Type de matériel (ex: Extincteur CO2)', prefixIcon: Icon(Icons.category_rounded)),
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _levelController,
                      decoration: const InputDecoration(labelText: 'Niveau (ex: RDC)', prefixIcon: Icon(Icons.layers_rounded)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Emplacement', prefixIcon: Icon(Icons.location_on_rounded)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(labelText: 'Marque', prefixIcon: Icon(Icons.branding_watermark_rounded)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _yearController,
                      decoration: const InputDecoration(labelText: 'Année fab.', prefixIcon: Icon(Icons.calendar_today_rounded)),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(labelText: 'Capacité / Modèle', prefixIcon: Icon(Icons.straighten_rounded)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(isEdit ? 'MODIFIER' : 'AJOUTER'),
        ),
      ],
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final e = widget.equipmentToEdit;
      final newEq = Equipment(
        id: e?.id ?? '', // Supabase will ignore if inserting new
        clientId: widget.clientId,
        type: _typeController.text,
        brand: _brandController.text,
        model: _modelController.text,
        location: _locationController.text,
        niveau: _levelController.text,
        manufactureYear: int.tryParse(_yearController.text),
        capacity: _capacityController.text,
        branche: _selectedBranche,
      );

      if (e == null) {
        await SupabaseService.instance.insertEquipment(newEq);
      } else {
        await SupabaseService.instance.updateEquipment(e.id, newEq);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Équipement enregistré')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
