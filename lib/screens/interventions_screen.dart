import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/responsive_layout.dart';

class InterventionsScreen extends StatefulWidget {
  const InterventionsScreen({super.key});

  @override
  State<InterventionsScreen> createState() => _InterventionsScreenState();
}

class _InterventionsScreenState extends State<InterventionsScreen> {
  String _statutFilter = 'Toutes';
  String _brancheFilter = 'Toutes';

  List<Intervention> get _filteredInterventions {
    return MockData.interventions.where((i) {
      final matchStatut = _statutFilter == 'Toutes' ||
          (_statutFilter == 'Planifiée' && i.statut == StatutIntervention.planifiee) ||
          (_statutFilter == 'Terminée' && i.statut == StatutIntervention.terminee) ||
          (_statutFilter == 'En cours' && i.statut == StatutIntervention.enCours);
      final matchBranche = _brancheFilter == 'Toutes' ||
          (_brancheFilter == 'Veriflamme' && i.branche == Branche.veriflamme) ||
          (_brancheFilter == 'Sauvdefib' && i.branche == Branche.sauvdefib);
      return matchStatut && matchBranche;
    }).toList()
      ..sort((a, b) => a.dateIntervention.compareTo(b.dateIntervention));
  }

  @override
  Widget build(BuildContext context) {
    final interventions = _filteredInterventions;
    final isMobile = ResponsiveLayout.isMobile(context);

    return AppScaffold(
      selectedIndex: 1,
      title: 'Interventions',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/new-intervention'),
            icon: const Icon(Icons.add, size: 18),
            label: Text(isMobile ? '' : 'Nouvelle intervention'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
            ),
          ),
        ),
      ],
      body: Column(
        children: [
          // Filters
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            child: isMobile
                ? Column(
                    children: [
                      _buildStatutFilter(),
                      const SizedBox(height: 12),
                      _buildBrancheFilter(),
                    ],
                  )
                : Row(
                    children: [
                      _buildStatutFilter(),
                      const SizedBox(width: 16),
                      _buildBrancheFilter(),
                      const Spacer(),
                      Text(
                        '${interventions.length} intervention(s)',
                        style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                      ),
                    ],
                  ),
          ),

          // List
          Expanded(
            child: interventions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.build_circle_outlined, size: 64, color: AppTheme.tertiaryText),
                        const SizedBox(height: 16),
                        Text('Aucune intervention trouvée',
                            style: TextStyle(color: AppTheme.secondaryText, fontSize: 15)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(isMobile ? 12 : 20),
                    itemCount: interventions.length,
                    itemBuilder: (context, index) {
                      return _buildInterventionCard(interventions[index], isMobile);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatutFilter() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'Toutes', label: Text('Toutes')),
        ButtonSegment(value: 'Planifiée', label: Text('Planifiée')),
        ButtonSegment(value: 'En cours', label: Text('En cours')),
        ButtonSegment(value: 'Terminée', label: Text('Terminée')),
      ],
      selected: {_statutFilter},
      onSelectionChanged: (v) => setState(() => _statutFilter = v.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildBrancheFilter() {
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
        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildInterventionCard(Intervention intervention, bool isMobile) {
    final client = MockData.clientById(intervention.clientId);
    final clientName = client?.raisonSociale ?? 'Client inconnu';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Détail intervention — en cours de développement'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isMobile
              ? _buildMobileInterventionCard(intervention, clientName)
              : _buildDesktopInterventionCard(intervention, clientName),
        ),
      ),
    );
  }

  Widget _buildMobileInterventionCard(Intervention intervention, String clientName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: intervention.branche.lightColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(intervention.branche.icon, color: intervention.branche.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(clientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(
                    '${intervention.typeIntervention == TypeIntervention.installation ? "Installation" : "Maintenance"} • ${intervention.periodicite.label}',
                    style: TextStyle(color: AppTheme.secondaryText, fontSize: 12),
                  ),
                ],
              ),
            ),
            _statutBadge(intervention.statut),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.secondaryText),
            const SizedBox(width: 6),
            Text(
              _formatDate(intervention.dateIntervention),
              style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
            ),
            const SizedBox(width: 16),
            Icon(Icons.person_outline, size: 14, color: AppTheme.secondaryText),
            const SizedBox(width: 6),
            Text(
              intervention.technicienNom,
              style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopInterventionCard(Intervention intervention, String clientName) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: intervention.branche.lightColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(intervention.branche.icon, color: intervention.branche.color, size: 22),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 120,
          child: Text(
            _formatDate(intervention.dateIntervention),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryText, fontSize: 14),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(clientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(
                '${intervention.typeIntervention == TypeIntervention.installation ? "Installation" : "Maintenance"} • ${intervention.periodicite.label}',
                style: TextStyle(color: AppTheme.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: AppTheme.secondaryText),
              const SizedBox(width: 6),
              Text(
                intervention.technicienNom,
                style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
              ),
            ],
          ),
        ),
        if (intervention.dureeMinutes != null)
          SizedBox(
            width: 80,
            child: Text(
              '${intervention.dureeMinutes} min',
              style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
            ),
          ),
        _statutBadge(intervention.statut),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, color: AppTheme.tertiaryText),
      ],
    );
  }

  Widget _statutBadge(StatutIntervention statut) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statut.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        statut.label,
        style: TextStyle(color: statut.color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
