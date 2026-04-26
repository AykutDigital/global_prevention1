import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../services/app_context_service.dart';
import '../../theme/app_theme.dart';

class ClientSelectionView extends StatelessWidget {
  final Technician? selectedTechnician;
  final List<Technician> technicians;
  final String? selectedClientId;
  final Function(Technician?) onTechnicianChanged;
  final Function(Client) onClientSelected;

  const ClientSelectionView({
    super.key,
    required this.selectedTechnician,
    required this.technicians,
    required this.selectedClientId,
    required this.onTechnicianChanged,
    required this.onClientSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Client & Intervenant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        if (SupabaseService.instance.currentTechnician?.isPlanner == true)
          DropdownButtonFormField<Technician>(
            value: selectedTechnician,
            decoration: const InputDecoration(
              labelText: 'Technicien intervenant',
              prefixIcon: Icon(Icons.person_rounded),
            ),
            items: technicians.map((t) => DropdownMenuItem(
              value: t,
              child: Text(t.nomComplet),
            )).toList(),
            onChanged: onTechnicianChanged,
          )
        else
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Technicien intervenant',
              prefixIcon: Icon(Icons.person_rounded),
            ),
            child: Text(
              selectedTechnician?.nomComplet ?? 'Non connecté',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        const SizedBox(height: 16),
        StreamBuilder<List<Client>>(
          stream: SupabaseService.instance.clientsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final clients = snapshot.data!.where((c) {
              final vfActive = AppContextService.instance.isVeriflammeActive.value;
              final sdActive = AppContextService.instance.isSauvdefibActive.value;
              return (c.isVeriflamme && vfActive) || (c.isSauvdefib && sdActive);
            }).toList();

            if (clients.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('Aucun client trouvé.'));

            return Column(
              children: clients.map((client) {
                final isSelected = selectedClientId == client.clientId;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected ? AppTheme.infoBlueLight : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? AppTheme.infoBlue : AppTheme.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    onTap: () => onClientSelected(client),
                    leading: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppTheme.infoBlue)
                        : const Icon(Icons.radio_button_unchecked, color: AppTheme.tertiaryText),
                    title: Text(
                      client.raisonSociale, 
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(client.ville ?? '', style: const TextStyle(fontSize: 12)),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
