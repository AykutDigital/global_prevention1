import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../services/supabase_service.dart';
import 'technicians_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final cols = ResponsiveLayout.gridColumns(context);

    return AppScaffold(
      selectedIndex: 5,
      title: 'Administration',
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paramètres & Configuration', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: isMobile ? 1.8 : 2.2,
              children: [
                _adminCard(context, Icons.people_rounded, 'Gestion techniciens', 'Ajouter, modifier ou désactiver des comptes techniciens.', AppTheme.infoBlue, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TechniciansScreen()));
                }),
                _adminCard(context, Icons.email_rounded, 'Configuration SMTP', 'Paramétrer le serveur e-mail pour l\'envoi des rapports et relances.', AppTheme.warningOrange),
                _adminCard(context, Icons.inventory_2_rounded, 'Catalogue matériaux', 'Gérer le catalogue de matériaux prédéfinis par branche.', AppTheme.sauvdefibGreen),
                _adminCard(context, Icons.bar_chart_rounded, 'Statistiques', 'Analyses et graphiques : conformité, coûts, fréquence clients.', AppTheme.primaryLight),
                _adminCard(context, Icons.download_rounded, 'Export CSV', 'Exporter les données clients, interventions et matériaux.', AppTheme.secondaryText),
                _adminCard(context, Icons.cloud_sync_rounded, 'Synchronisation cloud', 'État de la synchronisation et backup automatique.', AppTheme.infoBlue),
              ],
            ),
            const SizedBox(height: 32),
            Text('Informations système', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  _infoRow('Version', '1.0.0-beta'),
                  _infoRow('Base de données', 'Supabase (Cloud)'),
                  _infoRow('Synchronisation', 'Connecté'),
                  _infoRow('Dernière sauvegarde', 'En temps réel'),
                  _infoRow('Technicien connecté', SupabaseService.instance.currentTechnician?.nomComplet ?? 'Maxence Marseille'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminCard(BuildContext context, IconData icon, String title, String desc, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title — en cours de développement'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AppTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: AppTheme.tertiaryText, size: 20),
            ]),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(color: AppTheme.secondaryText, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(flex: 3, child: Text(label, style: TextStyle(color: AppTheme.secondaryText, fontSize: 13))),
        Expanded(flex: 4, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
      ]),
    );
  }
}
