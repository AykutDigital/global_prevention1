import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/responsive_layout.dart';

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final interventions = MockData.interventionsForClient(client.clientId);
    final relances = MockData.relancesForClient(client.clientId);
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
            onPressed: () => _showSnackbar('Modification en cours de développement'),
            tooltip: 'Modifier',
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _showSnackbar('$value — en cours de développement'),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'intervention', child: Text('Nouvelle intervention')),
              const PopupMenuItem(value: 'relance', child: Text('Envoyer relance')),
              const PopupMenuItem(value: 'archiver', child: Text('Archiver le client')),
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
          _buildInterventionsTab(interventions),
          _buildPlaceholderTab(Icons.description_rounded, 'Rapports', 'Les rapports associés à ce client seront affichés ici.'),
          _buildRelancesTab(relances, client),
          _buildPlaceholderTab(Icons.inventory_2_rounded, 'Équipements', 'La liste des équipements installés sur site sera affichée ici.'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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

  Widget _buildInterventionsTab(List<Intervention> interventions) {
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
            trailing: Container(
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
            onTap: () => _showSnackbar('Détail intervention — en cours de développement'),
          ),
        );
      },
    );
  }

  Widget _buildRelancesTab(List<Relance> relances, Client client) {
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
                'Échéance : ${_formatDate(r.dateEcheance)} • ${r.nbRelancesEnvoyees} relance(s) envoyée(s)',
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

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
