import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../widgets/responsive_layout.dart';
import 'package:uuid/uuid.dart';
import 'arborescence_preview_screen.dart';

class ArborescenceScreen extends StatefulWidget {
  final String clientId;
  final String? raisonSociale;
  final String? interventionId;

  const ArborescenceScreen({
    super.key,
    required this.clientId,
    this.raisonSociale,
    this.interventionId,
  });

  @override
  State<ArborescenceScreen> createState() => _ArborescenceScreenState();
}

class _ArborescenceScreenState extends State<ArborescenceScreen> {
  final Map<String, bool> _expandedNodes = {};
  List<Node> _currentNodes = [];
  List<InterventionAction> _actions = [];
  bool _isLoading = true;
  StreamSubscription<List<Node>>? _nodesSubscription;

  @override
  void initState() {
    super.initState();
    _loadActions();
    _nodesSubscription = SupabaseService.instance
        .nodesStream(widget.clientId)
        .listen((nodes) {
      if (mounted) setState(() { _currentNodes = nodes; _isLoading = false; });
    });
  }

  @override
  void dispose() {
    _nodesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadActions() async {
    if (widget.interventionId != null) {
      final actions = await SupabaseService.instance.getInterventionActions(widget.interventionId!);
      if (mounted) setState(() => _actions = actions);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Arborescence : ${widget.raisonSociale ?? "Client"}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Télécharger l\'arborescence',
            onPressed: _currentNodes.isEmpty ? null : _downloadArborescence,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => _showHelp(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentNodes.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildNodeList(_buildTree(_currentNodes), 'root', 0),
                    const SizedBox(height: 80),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddNodeDialog(null, 'root'),
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Ajouter un Bâtiment'),
      ),
    );
  }

  Map<String, List<Node>> _buildTree(List<Node> nodes) {
    final Map<String, List<Node>> tree = {};
    for (var node in nodes) {
      final parentId = node.parentId ?? 'root';
      if (!tree.containsKey(parentId)) {
        tree[parentId] = [];
      }
      tree[parentId]!.add(node);
    }
    return tree;
  }

  Widget _buildNodeList(Map<String, List<Node>> tree, String parentId, int level) {
    final children = tree[parentId] ?? [];
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      children: children.map((node) => _buildNodeTile(node, tree, level, key: ValueKey(node.id))).toList(),
    );
  }

  Widget _buildNodeTile(Node node, Map<String, List<Node>> tree, int level, {Key? key}) {
    final hasChildren = tree.containsKey(node.id);
    final isExpanded = _expandedNodes[node.id] ?? false;
    final isEquipment = node.type == 'equipment';

    return Column(
      key: key,
      children: [
        InkWell(
          onTap: () {
            if (isEquipment && widget.interventionId != null) {
              _showEquipmentValidation(node);
            } else if (!isEquipment) {
              setState(() => _expandedNodes[node.id] = !isExpanded);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: EdgeInsets.only(
              left: 8.0 + (level * 24.0),
              right: 8.0,
              top: 10.0,
              bottom: 10.0,
            ),
            decoration: BoxDecoration(
              color: isEquipment ? Colors.white : AppTheme.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isEquipment ? AppTheme.divider : Colors.transparent),
            ),
            child: Row(
              children: [
                if (!isEquipment)
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                    size: 20,
                    color: AppTheme.secondaryText,
                  )
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                Icon(
                  _getIconForType(node.type),
                  size: 18,
                  color: _getColorForType(node.type),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              node.label,
                              style: TextStyle(
                                fontWeight: isEquipment ? FontWeight.w600 : FontWeight.bold,
                                fontSize: isEquipment ? 14 : 15,
                              ),
                            ),
                          ),
                          if (isEquipment && widget.interventionId != null) 
                            _buildActionStatus(node.id),
                        ],
                      ),
                      if (node.category != null)
                        Text(
                          node.category!,
                          style: const TextStyle(fontSize: 11, color: AppTheme.secondaryText),
                        ),
                    ],
                  ),
                ),
                _buildNodeActions(node),
              ],
            ),
          ),
        ),
        if (isExpanded && !isEquipment)
          _buildNodeList(tree, node.id, level + 1),
      ],
    );
  }

  Widget _buildNodeActions(Node node) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (node.type != 'equipment')
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            onPressed: () => _showAddNodeDialog(node, node.id),
            tooltip: 'Ajouter un enfant',
            visualDensity: VisualDensity.compact,
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 20),
          onSelected: (val) {
            if (val == 'edit') _showEditNodeDialog(node);
            if (val == 'delete') _confirmDeleteNode(node);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Modifier')),
            const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: Colors.red))),
          ],
        ),
      ],
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'building': return Icons.business_rounded;
      case 'level': return Icons.layers_rounded;
      case 'zone': return Icons.grid_view_rounded;
      case 'room': return Icons.meeting_room_rounded;
      case 'equipment': return Icons.handyman_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'building': return AppTheme.primary;
      case 'level': return Colors.blueGrey;
      case 'zone': return Colors.orange;
      case 'room': return Colors.teal;
      case 'equipment': return AppTheme.veriflammeRed;
      default: return AppTheme.secondaryText;
    }
  }

  String _getChildType(String parentType) {
    switch (parentType) {
      case 'root': return 'building';
      case 'building': return 'level';
      case 'level': return 'zone';
      case 'zone': return 'room';
      case 'room': return 'equipment';
      default: return 'equipment';
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'building': return 'Bâtiment';
      case 'level': return 'Niveau';
      case 'zone': return 'Zone';
      case 'room': return 'Pièce / Emplacement';
      case 'equipment': return 'Équipement';
      default: return 'Élément';
    }
  }

  void _isCircularCheck(Node node) {
    if (node.parentId == null) return;
    String? current = node.parentId;
    final nodeMap = {for (var n in _currentNodes) n.id: n};
    while (current != null) {
      if (current == node.id) throw Exception('Boucle infinie détectée dans l\'arborescence');
      current = nodeMap[current]?.parentId;
    }
  }

  void _showAddNodeDialog(Node? parent, String parentId) {
    final type = _getChildType(parent?.type ?? 'root');
    final controller = TextEditingController();
    String? selectedCategory;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Ajouter un ${_getTypeLabel(type)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nom / Libellé',
                  hintText: parent != null ? 'Dans ${parent.label}' : 'Ex: Bâtiment A',
                ),
              ),
              if (type == 'equipment') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: const [
                    DropdownMenuItem(value: 'Extincteur', child: Text('Extincteur')),
                    DropdownMenuItem(value: 'RIA', child: Text('RIA')),
                    DropdownMenuItem(value: 'Désenfumage', child: Text('Désenfumage')),
                    DropdownMenuItem(value: 'Alarme Incendie', child: Text('Alarme Incendie')),
                    DropdownMenuItem(value: 'DAE', child: Text('DAE')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedCategory = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
            ElevatedButton(
              onPressed: () {
                final newNode = Node(
                  id: const Uuid().v4(),
                  clientId: widget.clientId,
                  parentId: parentId == 'root' ? null : parentId,
                  label: controller.text,
                  type: type,
                  category: selectedCategory,
                  createdAt: DateTime.now(),
                );

                try {
                  _isCircularCheck(newNode);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                  return;
                }

                // Mise à jour immédiate de l'UI
                setState(() {
                  _currentNodes = [..._currentNodes, newNode]..sort((a, b) => a.label.compareTo(b.label));
                  if (parentId != 'root') _expandedNodes[parentId] = true;
                });
                Navigator.pop(context);

                final messenger = ScaffoldMessenger.of(context);
                SupabaseService.instance.upsertNode(newNode, allNodes: _currentNodes).catchError((e) {
                  if (mounted) messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                });
              },
              child: const Text('AJOUTER'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNodeDialog(Node node) {
    final controller = TextEditingController(text: node.label);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier ${_getTypeLabel(node.type)}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nom / Libellé'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          ElevatedButton(
            onPressed: () {
              final updated = node.copyWith(label: controller.text);
              try {
                SupabaseService.instance.upsertNode(updated, allNodes: _currentNodes);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
              }
            },
            child: const Text('ENREGISTRER'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteNode(Node node) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'élément ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Voulez-vous supprimer "${node.label}" ?\n\nAttention: tous les éléments enfants seront également supprimés.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motif de suppression (Obligatoire)',
                hintText: 'Ex: Équipement retiré du site, erreur de saisie...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le motif est obligatoire')));
                return;
              }
              SupabaseService.instance.deleteNode(node.id, reason: reasonController.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SUPPRIMER'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_tree_rounded, size: 64, color: AppTheme.tertiaryText.withOpacity(0.5)),
          const SizedBox(height: 24),
          const Text(
            'Arborescence vide',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Commencez par ajouter un bâtiment ou une zone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddNodeDialog(null, 'root'),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter le premier élément'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionStatus(String nodeId) {
    final action = _actions.where((a) => a.nodeId == nodeId).firstOrNull;
    if (action == null) return const SizedBox.shrink();

    final status = StatutElement.values.firstWhere((s) => s.label == action.status, orElse: () => StatutElement.v);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: status.color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: status.color.withOpacity(0.3))),
      child: Text(status.label, style: TextStyle(color: status.color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showEquipmentValidation(Node node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vérification : ${node.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: StatutElement.values.map((s) => ListTile(
            leading: Icon(Icons.circle, color: s.color, size: 16),
            title: Text(s.fullLabel),
            trailing: Text(s.label, style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () async {
              final action = InterventionAction(
                id: '', 
                interventionId: widget.interventionId!,
                nodeId: node.id,
                status: s.label,
                createdAt: DateTime.now(),
              );
              await SupabaseService.instance.saveInterventionAction(action);
              _loadActions();
              if (mounted) Navigator.pop(context);
            },
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
        ],
      ),
    );
  }

  void _downloadArborescence() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArborescencePreviewScreen(
          clientId: widget.clientId,
          raisonSociale: widget.raisonSociale ?? 'Client',
          nodes: _currentNodes,
          actions: _actions,
        ),
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aide Arborescence'),
        content: const Text(
          'L\'arborescence permet d\'organiser les équipements par structure logique :\n\n'
          '1. Bâtiment\n'
          '2. Niveau (Étage)\n'
          '3. Zone (Aile, Atelier...)\n'
          '4. Pièce / Emplacement\n'
          '5. Équipement\n\n'
          'Les techniciens peuvent modifier cette structure en temps réel sur le terrain.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}
