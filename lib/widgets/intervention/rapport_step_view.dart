import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'dart:io';

class RapportStepView extends StatelessWidget {
  final Branche selectedBranche;
  final List<Equipment> equipments;
  final List<EquipmentMaintenanceLine> equipmentChecks;
  final Conformite selectedConformite;
  final TextEditingController recommandationsController;
  final Function(Equipment) onVerifyEquipment;
  final Function({Equipment? equipmentToEdit}) onAddEquipment;
  final Function(String) onCapturePhoto;
  final Function(Conformite) onConformiteChanged;
  final VoidCallback onOpenPreview;

  const RapportStepView({
    super.key,
    required this.selectedBranche,
    required this.equipments,
    required this.equipmentChecks,
    required this.selectedConformite,
    required this.recommandationsController,
    required this.onVerifyEquipment,
    required this.onAddEquipment,
    required this.onCapturePhoto,
    required this.onConformiteChanged,
    required this.onOpenPreview,
  });

  @override
  Widget build(BuildContext context) {
    final checkedCount = equipmentChecks.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Saisie du rapport technique', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        
        Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: equipments.isEmpty ? 0 : checkedCount / equipments.length,
              backgroundColor: AppTheme.divider,
              color: checkedCount == equipments.length ? AppTheme.successGreen : AppTheme.infoBlue,
              minHeight: 6,
            ),
          )),
          const SizedBox(width: 12),
          Text('$checkedCount / ${equipments.length} vérifiés',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: checkedCount == equipments.length ? AppTheme.successGreen : AppTheme.secondaryText)),
        ]),
        
        const SizedBox(height: 16),
        
        ...equipments.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final eq = entry.value;
          final isChecked = equipmentChecks.any((c) => c.equipmentId == eq.id);
          final check = equipmentChecks.where((c) => c.equipmentId == eq.id).firstOrNull;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: isChecked ? AppTheme.successGreen : AppTheme.divider,
                child: Text('$idx', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              title: Text('${eq.type} - ${eq.location ?? "Sans emplacement"}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              trailing: Wrap(
                children: [
                  if (isChecked) const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 20),
                  IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => onVerifyEquipment(eq)),
                ],
              ),
            ),
          );
        }).toList(),
        
        const SizedBox(height: 24),
        DropdownButtonFormField<Conformite>(
          value: selectedConformite,
          decoration: const InputDecoration(labelText: 'Conformité globale'),
          items: Conformite.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
          onChanged: (v) => onConformiteChanged(v!),
        ),
        
        const SizedBox(height: 16),
        TextFormField(
          controller: recommandationsController,
          decoration: const InputDecoration(labelText: 'Observations et Préconisations'),
          maxLines: 3,
        ),
        
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: onOpenPreview,
          icon: const Icon(Icons.visibility),
          label: const Text('VOIR LA PRÉVISUALISATION'),
          style: ElevatedButton.styleFrom(backgroundColor: selectedBranche.color, minimumSize: const Size(double.infinity, 50)),
        ),
      ],
    );
  }
}
