import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../services/app_context_service.dart';
import '../services/supabase_service.dart';

class RelancesScreen extends StatefulWidget {
  const RelancesScreen({super.key});
  @override
  State<RelancesScreen> createState() => _RelancesScreenState();
}

class _RelancesScreenState extends State<RelancesScreen> {
  String _urgencyFilter = 'Toutes';

  List<Relance> _filterRelances(List<Relance> allRelances, bool vfActive, bool sdActive) {
    final relances = allRelances
      .where((r) => (r.branche == Branche.veriflamme && vfActive) || (r.branche == Branche.sauvdefib && sdActive))
      .toList()
      ..sort((a, b) => a.dateEcheance.compareTo(b.dateEcheance));
      
    if (_urgencyFilter == 'Urgentes') return relances.where((r) => r.joursRestants <= 7).toList();
    if (_urgencyFilter == 'Proches') return relances.where((r) => r.joursRestants > 7 && r.joursRestants <= 30).toList();
    if (_urgencyFilter == 'À venir') return relances.where((r) => r.joursRestants > 30).toList();
    return relances;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    return AppScaffold(
      selectedIndex: 4,
      title: 'Relances maintenance',
      body: ValueListenableBuilder<bool>(
        valueListenable: AppContextService.instance.isVeriflammeActive,
        builder: (context, vfActive, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: AppContextService.instance.isSauvdefibActive,
            builder: (context, sdActive, _) {
              return StreamBuilder<List<Client>>(
                stream: SupabaseService.instance.clientsStream,
                builder: (context, clientSnapshot) {
                  return StreamBuilder<List<Relance>>(
                    stream: SupabaseService.instance.relancesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final allRelances = snapshot.data ?? [];
                      final relances = _filterRelances(allRelances, vfActive, sdActive);
                      final clients = clientSnapshot.data ?? [];
                      final clientMap = {for (var c in clients) c.clientId: c.raisonSociale};

                      final urgentes = allRelances.where((r) => ((r.branche == Branche.veriflamme && vfActive) || (r.branche == Branche.sauvdefib && sdActive)) && r.joursRestants <= 7).length;
                      final proches = allRelances.where((r) => ((r.branche == Branche.veriflamme && vfActive) || (r.branche == Branche.sauvdefib && sdActive)) && r.joursRestants > 7 && r.joursRestants <= 30).length;
                      final aVenir = allRelances.where((r) => ((r.branche == Branche.veriflamme && vfActive) || (r.branche == Branche.sauvdefib && sdActive)) && r.joursRestants > 30).length;

                      return CustomScrollView(
                        slivers: [
                          // Header (Cards + Filter)
                          SliverToBoxAdapter(
                            child: Container(
                              padding: EdgeInsets.all(isMobile ? 12 : 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(bottom: BorderSide(color: AppTheme.divider)),
                              ),
                              child: isMobile
                                  ? Column(children: [
                                      Row(children: [
                                        Expanded(child: _summaryCard('Urgentes', '$urgentes', AppTheme.veriflammeRed, Icons.error_rounded)),
                                        const SizedBox(width: 10),
                                        Expanded(child: _summaryCard('< 30j', '$proches', AppTheme.warningOrange, Icons.schedule_rounded)),
                                        const SizedBox(width: 10),
                                        Expanded(child: _summaryCard('À venir', '$aVenir', AppTheme.sauvdefibGreen, Icons.check_circle_rounded)),
                                      ]),
                                      const SizedBox(height: 12),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: _buildFilter(),
                                      ),
                                    ])
                                  : Row(children: [
                                      _summaryCard('Urgentes (≤7j)', '$urgentes', AppTheme.veriflammeRed, Icons.error_rounded),
                                      const SizedBox(width: 12),
                                      _summaryCard('Proches (≤30j)', '$proches', AppTheme.warningOrange, Icons.schedule_rounded),
                                      const SizedBox(width: 12),
                                      _summaryCard('À venir', '$aVenir', AppTheme.sauvdefibGreen, Icons.check_circle_rounded),
                                      const Spacer(),
                                      _buildFilter(),
                                    ]),
                            ),
                          ),

                          // Content Area
                          if (relances.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min, 
                                  children: [
                                    Icon(Icons.notifications_off_rounded, size: 64, color: AppTheme.tertiaryText),
                                    const SizedBox(height: 16),
                                    Text('Aucune relance', style: TextStyle(color: AppTheme.secondaryText)),
                                  ]
                                )
                              ),
                            )
                          else
                            SliverPadding(
                              padding: EdgeInsets.all(isMobile ? 12 : 20),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (ctx, i) {
                                    final r = relances[i];
                                    final clientName = clientMap[r.clientId] ?? 'Client inconnu';
                                    return _buildCard(r, clientName, isMobile);
                                  },
                                  childCount: relances.length,
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
      ),
    );
  }

  Widget _buildFilter() => SegmentedButton<String>(
    segments: const [
      ButtonSegment(value: 'Toutes', label: Text('Toutes')),
      ButtonSegment(value: 'Urgentes', label: Text('Urgentes')),
      ButtonSegment(value: 'Proches', label: Text('Proches')),
      ButtonSegment(value: 'À venir', label: Text('À venir')),
    ],
    selected: {_urgencyFilter},
    onSelectionChanged: (v) => setState(() => _urgencyFilter = v.first),
    style: ButtonStyle(visualDensity: VisualDensity.compact,
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
  );

  Widget _summaryCard(String label, String value, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    ]),
  );

  Widget _buildCard(Relance r, String clientName, bool isMobile) {
    final j = r.joursRestants;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Détail relance — en développement'), behavior: SnackBarBehavior.floating)),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: r.urgencyColor, width: 4))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: r.branche.lightColor, borderRadius: BorderRadius.circular(8)),
              child: Icon(r.branche.icon, color: r.branche.color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(clientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text('${r.typeMaintenance.label} • Éch. ${_fmt(r.dateEcheance)} • ${r.nbRelancesEnvoyees} envoi(s)',
                style: TextStyle(color: AppTheme.secondaryText, fontSize: 12)),
            ])),
            _urgencyBadge(j),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.send_rounded, size: 18), color: AppTheme.infoBlue,
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Envoi relance — en développement'), behavior: SnackBarBehavior.floating)), tooltip: 'Envoyer'),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _urgencyBadge(int j) {
    final color = j < 0 ? AppTheme.veriflammeRed : (j <= 7 ? AppTheme.veriflammeRed : (j <= 30 ? AppTheme.warningOrange : AppTheme.sauvdefibGreen));
    final label = j < 0 ? 'J+${-j}' : 'J-$j';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
