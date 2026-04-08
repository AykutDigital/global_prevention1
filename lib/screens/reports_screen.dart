import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/responsive_layout.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _brancheFilter = 'Toutes';

  List<Rapport> get _filteredRapports {
    return MockData.rapports.where((r) {
      return _brancheFilter == 'Toutes' ||
          (_brancheFilter == 'Veriflamme' && r.branche == Branche.veriflamme) ||
          (_brancheFilter == 'Sauvdefib' && r.branche == Branche.sauvdefib);
    }).toList()
      ..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
  }

  @override
  Widget build(BuildContext context) {
    final rapports = _filteredRapports;
    final isMobile = ResponsiveLayout.isMobile(context);

    return AppScaffold(
      selectedIndex: 3,
      title: 'Rapports',
      body: Column(
        children: [
          // Filters
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Toutes', label: Text('Toutes')),
                    ButtonSegment(value: 'Veriflamme', icon: Icon(Icons.local_fire_department, size: 16), label: Text('VF')),
                    ButtonSegment(value: 'Sauvdefib', icon: Icon(Icons.medical_services, size: 16), label: Text('SD')),
                  ],
                  selected: {_brancheFilter},
                  onSelectionChanged: (v) => setState(() => _brancheFilter = v.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ),
                const Spacer(),
                Text(
                  '${rapports.length} rapport(s)',
                  style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                ),
              ],
            ),
          ),

          // Reports list
          Expanded(
            child: rapports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, size: 64, color: AppTheme.tertiaryText),
                        const SizedBox(height: 16),
                        Text('Aucun rapport trouvé', style: TextStyle(color: AppTheme.secondaryText)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(isMobile ? 12 : 20),
                    itemCount: rapports.length,
                    itemBuilder: (context, index) {
                      return _buildRapportCard(rapports[index], isMobile);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRapportCard(Rapport rapport, bool isMobile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isMobile
            ? _buildMobileRapportCard(rapport)
            : _buildDesktopRapportCard(rapport),
      ),
    );
  }

  Widget _buildMobileRapportCard(Rapport rapport) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: rapport.branche.lightColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(rapport.branche.icon, color: rapport.branche.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rapport.numeroRapport,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(
                    '${rapport.typeRapport == TypeIntervention.installation ? "Installation" : "Maintenance"} • ${_formatDate(rapport.dateCreation)}',
                    style: TextStyle(color: AppTheme.secondaryText, fontSize: 12),
                  ),
                ],
              ),
            ),
            _conformiteBadge(rapport.conformite),
          ],
        ),
        if (rapport.recommandations != null) ...[
          const SizedBox(height: 12),
          Text(
            rapport.recommandations!,
            style: TextStyle(color: AppTheme.secondaryText, fontSize: 13, fontStyle: FontStyle.italic),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            _actionChip(
              Icons.picture_as_pdf_rounded,
              'PDF',
              AppTheme.veriflammeRed,
              () => _showSnackbar('Visualisation PDF — en développement'),
            ),
            const SizedBox(width: 8),
            _actionChip(
              rapport.emailEnvoye ? Icons.mark_email_read_rounded : Icons.email_rounded,
              rapport.emailEnvoye ? 'Envoyé' : 'Envoyer',
              rapport.emailEnvoye ? AppTheme.sauvdefibGreen : AppTheme.infoBlue,
              () => _showSnackbar(rapport.emailEnvoye
                  ? 'Envoyé le ${_formatDate(rapport.dateEnvoiEmail!)}'
                  : 'Envoi par email — en développement'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopRapportCard(Rapport rapport) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: rapport.branche.lightColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(rapport.branche.icon, color: rapport.branche.color, size: 22),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 140,
          child: Text(rapport.numeroRapport,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        SizedBox(
          width: 120,
          child: Text(_formatDate(rapport.dateCreation),
              style: TextStyle(color: AppTheme.secondaryText, fontSize: 13)),
        ),
        SizedBox(
          width: 120,
          child: Text(
            rapport.typeRapport == TypeIntervention.installation ? 'Installation' : 'Maintenance',
            style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
          ),
        ),
        Expanded(
          child: rapport.recommandations != null
              ? Text(
                  rapport.recommandations!,
                  style: TextStyle(color: AppTheme.secondaryText, fontSize: 13, fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : const SizedBox(),
        ),
        const SizedBox(width: 12),
        _conformiteBadge(rapport.conformite),
        const SizedBox(width: 12),
        _actionChip(
          Icons.picture_as_pdf_rounded,
          'PDF',
          AppTheme.veriflammeRed,
          () => _showSnackbar('Visualisation PDF — en développement'),
        ),
        const SizedBox(width: 8),
        _actionChip(
          rapport.emailEnvoye ? Icons.mark_email_read_rounded : Icons.email_rounded,
          rapport.emailEnvoye ? 'Envoyé' : 'Envoyer',
          rapport.emailEnvoye ? AppTheme.sauvdefibGreen : AppTheme.infoBlue,
          () => _showSnackbar(rapport.emailEnvoye
              ? 'Envoyé le ${_formatDate(rapport.dateEnvoiEmail!)}'
              : 'Envoi par email — en développement'),
        ),
      ],
    );
  }

  Widget _conformiteBadge(Conformite conformite) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: conformite.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        conformite.label,
        style: TextStyle(
          color: conformite.color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }
}
