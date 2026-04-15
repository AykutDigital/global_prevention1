import 'dart:io';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../services/app_context_service.dart';
import '../services/supabase_service.dart';
import '../widgets/image_viewer.dart';
import 'report_preview_screen.dart';

class InterventionsScreen extends StatefulWidget {
  const InterventionsScreen({super.key});

  @override
  State<InterventionsScreen> createState() => _InterventionsScreenState();
}

class _InterventionsScreenState extends State<InterventionsScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    // Normalize to date only
    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _focusedDay = _selectedDate;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _focusedDay = _selectedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    return AppScaffold(
      selectedIndex: 1,
      title: 'Planning & Interventions',
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
      body: ValueListenableBuilder<bool>(
        valueListenable: AppContextService.instance.isVeriflammeActive,
        builder: (context, vfActive, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: AppContextService.instance.isSauvdefibActive,
            builder: (context, sdActive, _) {
              return Column(
                children: [
                  // 1. Navigation par date (Vue du jour)
                  _buildDayNavigator(context, isMobile),

                  // 2. Liste des interventions du jour
                  Expanded(
                    child: StreamBuilder<List<Intervention>>(
                      stream: SupabaseService.instance.interventionsByDateStream(_selectedDate),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final interventions = (snapshot.data ?? []).where((i) {
                          final matchesGlobalVF = vfActive && i.branche == Branche.veriflamme;
                          final matchesGlobalSD = sdActive && i.branche == Branche.sauvdefib;
                          return matchesGlobalVF || matchesGlobalSD;
                        }).toList();

                        return StreamBuilder<List<Client>>(
                          stream: SupabaseService.instance.clientsStream,
                          builder: (context, clientSnapshot) {
                            final clients = clientSnapshot.data ?? [];
                            final clientMap = {for (var c in clients) c.clientId: c};

                            if (interventions.isEmpty) {
                              return _buildEmptyState();
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: interventions.length,
                              itemBuilder: (context, index) {
                                final intervention = interventions[index];
                                final client = clientMap[intervention.clientId];
                                return _buildInterventionCard(intervention, client, isMobile);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // 3. Calendrier mensuel en bas (Sticky/Bottom)
                  _buildMonthlyCalendar(vfActive, sdActive),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDayNavigator(BuildContext context, bool isMobile) {
    final dayLabel = DateFormat('EEEE d MMMM', 'fr_FR').format(_selectedDate);
    final isToday = isSameDay(_selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _changeDate(-1),
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            color: AppTheme.primary,
          ),
          InkWell(
            onTap: () => _selectDate(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  Text(
                    dayLabel.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isToday ? AppTheme.primary : AppTheme.primaryText,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      height: 3,
                      width: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  else
                    Text(
                      'Cliquer pour changer',
                      style: TextStyle(color: AppTheme.secondaryText, fontSize: 10),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => _changeDate(1),
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            color: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: AppTheme.tertiaryText.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Pas d\'interventions prévues pour ce jour',
            style: TextStyle(color: AppTheme.secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInterventionCard(Intervention intervention, Client? client, bool isMobile) {
    final clientName = client?.raisonSociale ?? 'Client inconnu';
    final city = client?.ville ?? '-';
    
    // Formatting time
    String timeRange = '';
    if (intervention.startTime != null) {
      timeRange = intervention.startTime!;
      if (intervention.endTime != null) {
        timeRange += ' - ${intervention.endTime}';
      }
    } else {
      timeRange = DateFormat('HH:mm').format(intervention.scheduledDate);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Time/Icon Section
                Container(
                  width: 65,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        timeRange.split(' - ').first,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Icon(intervention.branche.icon, color: intervention.branche.color, size: 18),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // Info Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 12, color: AppTheme.tertiaryText),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              city, 
                              style: TextStyle(color: AppTheme.secondaryText, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 12, color: AppTheme.tertiaryText),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              intervention.technicienNom, 
                              style: TextStyle(color: AppTheme.secondaryText, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Status Badge
                _buildStatusBadge(intervention.statut),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            
            // Type & Actions Section (Vertical orientation to prevent overlaps)
            Row(
              children: [
                Icon(
                  intervention.typeIntervention == TypeIntervention.installation ? Icons.rocket_launch_rounded : Icons.handyman_rounded,
                  size: 14,
                  color: AppTheme.infoBlue,
                ),
                const SizedBox(width: 4),
                Text(
                  intervention.typeIntervention == TypeIntervention.installation ? "INSTALLATION" : "MAINTENANCE",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppTheme.infoBlue, letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _showPhotosModal(intervention),
                    icon: const Icon(Icons.photo_library_rounded, size: 16),
                    label: const Text('Photos', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.withOpacity(0.05),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showQuickEditModal(intervention),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Modifier', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.withOpacity(0.05),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _handleReportPressed(intervention),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Rapport', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDeleteIntervention(intervention),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                    label: const Text('Supprimer', style: TextStyle(fontSize: 12, color: Colors.red)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.05),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteIntervention(Intervention intervention) async {
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('SUPPRIMER'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Supprimer le rapport lié s'il existe
        final rapport = await SupabaseService.instance.getRapportByInterventionId(intervention.interventionId);
        if (rapport != null) {
          await SupabaseService.instance.deleteRapport(rapport.rapportId);
        }
        // Supprimer l'intervention
        await SupabaseService.instance.deleteIntervention(intervention.interventionId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Intervention supprimée.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildStatusBadge(StatutIntervention statut) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statut.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statut.color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        statut.label.toUpperCase(),
        style: TextStyle(
          color: statut.color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMonthlyCalendar(bool vfActive, bool sdActive) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: StreamBuilder<List<Intervention>>(
        stream: SupabaseService.instance.interventionsStream,
        builder: (context, snapshot) {
          final interventions = snapshot.data ?? [];
          
          return TableCalendar<Intervention>(
            locale: 'fr_FR',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Mois',
            },
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              leftChevronIcon: Icon(Icons.chevron_left, size: 20),
              rightChevronIcon: Icon(Icons.chevron_right, size: 20),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              markerSize: 6,
              todayDecoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
              selectedDecoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDate = DateTime(selected.year, selected.month, selected.day);
                _focusedDay = focused;
              });
            },
            onFormatChanged: (format) => setState(() => _calendarFormat = format),
            onPageChanged: (focused) => _focusedDay = focused,
            eventLoader: (day) {
              return interventions.where((i) {
                final matchDay = isSameDay(i.scheduledDate, day);
                final matchActive = (i.branche == Branche.veriflamme && vfActive) || 
                                     (i.branche == Branche.sauvdefib && sdActive);
                return matchDay && matchActive;
              }).toList();
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: events.take(3).map((e) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: e.branche.color,
                    ),
                  )).toList(),
                );
              },
            ),
            rowHeight: 42,
            daysOfWeekHeight: 20,
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              weekendStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleReportPressed(Intervention intervention) async {
    // 1. Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final supabase = SupabaseService.instance;
      
      // 2. Fetch Client and Report
      final client = await supabase.getClientById(intervention.clientId);
      final report = await supabase.getRapportByInterventionId(intervention.interventionId);

      // 3. Hide loading
      if (mounted) Navigator.of(context).pop();

      if (client == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de trouver le client.')));
        return;
      }

      if (report == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le rapport n\'a pas encore été généré pour cette intervention.')));
        return;
      }

      // 4. Navigate to preview
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ReportPreviewScreen(
              client: client,
              intervention: intervention,
              rapport: report,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Safety hide
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  void _showPhotosModal(Intervention intervention) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => _InterventionPhotosModal(intervention: intervention),
    );
  }

  void _showQuickEditModal(Intervention intervention) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => _QuickEditModal(intervention: intervention),
    );
  }
}

class _QuickEditModal extends StatefulWidget {
  final Intervention intervention;
  const _QuickEditModal({required this.intervention});

  @override
  State<_QuickEditModal> createState() => _QuickEditModalState();
}

class _QuickEditModalState extends State<_QuickEditModal> {
  late StatutIntervention _tempStatut;
  late DateTime _tempDate;
  late TimeOfDay _tempStartTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tempStatut = widget.intervention.statut;
    _tempDate = widget.intervention.scheduledDate;
    final timeStr = widget.intervention.startTime ?? "08:00";
    final parts = timeStr.split(':');
    _tempStartTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Modification Rapide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 20),
          
          const Text('Statut de l\'intervention', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: StatutIntervention.values.map((s) {
              final isSelected = _tempStatut == s;
              return ChoiceChip(
                label: Text(s.label, style: TextStyle(color: isSelected ? Colors.white : s.color, fontSize: 12)),
                selected: isSelected,
                selectedColor: s.color,
                onSelected: (val) => setState(() => _tempStatut = s),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(context: context, initialDate: _tempDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (d != null) setState(() => _tempDate = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: AppTheme.divider), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 8),
                            Text(DateFormat('dd/MM/yyyy').format(_tempDate)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Heure', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: _tempStartTime);
                        if (t != null) setState(() => _tempStartTime = t);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: AppTheme.divider), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 16),
                            const SizedBox(width: 8),
                            Text(_tempStartTime.format(context)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () async {
                setState(() => _isSaving = true);
                
                final startStr = '${_tempStartTime.hour.toString().padLeft(2, '0')}:${_tempStartTime.minute.toString().padLeft(2, '0')}';
                final updated = widget.intervention.copyWith(
                  statut: _tempStatut,
                  scheduledDate: _tempDate,
                  startTime: startStr,
                  updatedAt: DateTime.now(),
                );
                
                try {
                  await SupabaseService.instance.updateIntervention(updated);
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Intervention mise à jour')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('ENREGISTRER LES MODIFICATIONS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InterventionPhotosModal extends StatefulWidget {
  final Intervention intervention;
  const _InterventionPhotosModal({required this.intervention});

  @override
  State<_InterventionPhotosModal> createState() => _InterventionPhotosModalState();
}

class _InterventionPhotosModalState extends State<_InterventionPhotosModal> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _addPhoto(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: 1024,
    );
    
    if (image != null) {
      if (!mounted) return;
      setState(() => _isUploading = true);
      try {
        await SupabaseService.instance.uploadInterventionPhoto(widget.intervention.interventionId, File(image.path));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo ajoutée')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Photos d\'intervention', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Réf: ${widget.intervention.interventionId.substring(0, 8)}', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(height: 30),
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: LinearProgressIndicator(),
            ),
          Expanded(
            child: StreamBuilder<List<InterventionPhoto>>(
              stream: SupabaseService.instance.getInterventionPhotosStream(widget.intervention.interventionId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final photos = snapshot.data ?? [];
                if (photos.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.no_photography_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Aucune photo pour le moment', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: photo.url))),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Hero(
                              tag: photo.url,
                              child: Image.network(photo.url, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -5,
                          top: -5,
                          child: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.delete_forever, color: Colors.white, size: 16),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Supprimer la photo ?'),
                                  content: const Text('Cette action est irréversible.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULER')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('SUPPRIMER', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await SupabaseService.instance.deleteInterventionPhoto(photo.id, photo.url);
                              }
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Caméra'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Galerie'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
