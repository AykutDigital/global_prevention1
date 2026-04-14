import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import 'report_preview_screen.dart';

class ClientReportsDetailScreen extends StatefulWidget {
  final Client client;
  final Map<Branche, List<Rapport>> branches;
  final List<Intervention> allInterventions;

  const ClientReportsDetailScreen({
    super.key,
    required this.client,
    required this.branches,
    required this.allInterventions,
  });

  @override
  State<ClientReportsDetailScreen> createState() => _ClientReportsDetailScreenState();
}

class _ClientReportsDetailScreenState extends State<ClientReportsDetailScreen> {
  bool _sortAscending = false;
  late List<Rapport> _vfRapports;
  late List<Rapport> _sdRapports;

  @override
  void initState() {
    super.initState();
    _vfRapports = List.from(widget.branches[Branche.veriflamme]!);
    _sdRapports = List.from(widget.branches[Branche.sauvdefib]!);
    _sortLocal();
  }

  void _sortLocal() {
    setState(() {
      _vfRapports.sort((a, b) => _sortAscending 
          ? a.dateCreation.compareTo(b.dateCreation) 
          : b.dateCreation.compareTo(a.dateCreation));
      
      _sdRapports.sort((a, b) => _sortAscending 
          ? a.dateCreation.compareTo(b.dateCreation) 
          : b.dateCreation.compareTo(a.dateCreation));
    });
  }

  void _toggleSort() {
    setState(() {
      _sortAscending = !_sortAscending;
      _sortLocal();
    });
  }

  Future<void> _confirmDelete(BuildContext context, Rapport rapport) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le rapport'),
        content: Text('Supprimer le rapport ${rapport.numeroRapport} ? Cette action est irréversible.'),
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
    await SupabaseService.instance.deleteRapport(rapport.rapportId);
    setState(() {
      _vfRapports.removeWhere((r) => r.rapportId == rapport.rapportId);
      _sdRapports.removeWhere((r) => r.rapportId == rapport.rapportId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.client.raisonSociale, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${widget.client.codeClient} • ${widget.client.ville}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          _sortToggle(),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_vfRapports.isNotEmpty)
              _buildBranchSection(context, Branche.veriflamme, _vfRapports),
            
            if (_vfRapports.isNotEmpty && _sdRapports.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(),
              ),

            if (_sdRapports.isNotEmpty)
              _buildBranchSection(context, Branche.sauvdefib, _sdRapports),
            
            if (_vfRapports.isEmpty && _sdRapports.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: Text('Aucun rapport disponible pour ce client.'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sortToggle() {
    return InkWell(
      onTap: _toggleSort,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.infoBlueLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.infoBlue.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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

  Widget _buildBranchSection(BuildContext context, Branche branche, List<Rapport> rapports) {
    // Group by TypeIntervention
    final Map<TypeIntervention, List<Rapport>> groupedByType = {};
    for (var r in rapports) {
      if (!groupedByType.containsKey(r.typeRapport)) {
        groupedByType[r.typeRapport] = [];
      }
      groupedByType[r.typeRapport]!.add(r);
    }

    // Sort the types using their enum index for a consistent order
    final sortedTypes = groupedByType.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(branche.icon, color: branche.color, size: 20),
            const SizedBox(width: 8),
            Text(
              branche.label.toUpperCase(),
              style: TextStyle(color: branche.color, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1),
            ),
            const Spacer(),
            Text('${rapports.length} rapport(s)', style: TextStyle(color: AppTheme.tertiaryText, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 16),
        ...sortedTypes.map((type) {
          final typeRapports = groupedByType[type]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 4.0),
                child: Text(
                  type.label,
                  style: TextStyle(color: AppTheme.secondaryText, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              ...typeRapports.map((r) {
                final intervention = widget.allInterventions.firstWhere(
                  (i) => i.interventionId == r.interventionId, 
                  orElse: () => widget.allInterventions.first
                );
                return _buildRapportTile(context, r, intervention);
              }),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildRapportTile(BuildContext context, Rapport rapport, Intervention intervention) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rapport.numeroRapport, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.tertiaryText),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${_formatDate(rapport.dateCreation)} • ${rapport.typeRapport.label}',
                        style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _conformiteBadge(rapport.conformite),
          const SizedBox(width: 16),
          IconButton(
            icon: Icon(Icons.visibility_rounded, color: AppTheme.primary, size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportPreviewScreen(
              client: widget.client,
              intervention: intervention,
              rapport: rapport,
            ))),
          ),
          if (SupabaseService.instance.currentTechnician?.isAdmin == true)
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 22),
              onPressed: () => _confirmDelete(context, rapport),
            ),
        ],
      ),
    );
  }

  Widget _conformiteBadge(Conformite conformite) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: conformite.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        conformite.label,
        style: TextStyle(color: conformite.color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
