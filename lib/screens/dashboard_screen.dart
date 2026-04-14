import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../services/app_context_service.dart';
import '../services/supabase_service.dart';
import '../repositories/client_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final isTablet = ResponsiveLayout.isTablet(context);

    return AppScaffold(
      selectedIndex: 2,
      title: 'Tableau de bord',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/new-intervention'),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle Intervention'),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: AppContextService.instance.isVeriflammeActive,
        builder: (context, vfActive, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: AppContextService.instance.isSauvdefibActive,
            builder: (context, sdActive, _) {
              return StreamBuilder<List<Client>>(
                stream: ClientRepository.instance.clientsStream,
                builder: (context, clientSnapshot) {
                  return StreamBuilder<List<Intervention>>(
                    stream: SupabaseService.instance.interventionsStream,
                    initialData: const [],
                    builder: (context, interventionSnapshot) {
                      return StreamBuilder<List<Relance>>(
                        stream: SupabaseService.instance.relancesStream,
                        initialData: const [],
                        builder: (context, relanceSnapshot) {
                          if (!clientSnapshot.hasData && clientSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final clients = clientSnapshot.data ?? [];
                          final interventions = interventionSnapshot.data ?? [];
                          final relances = relanceSnapshot.data ?? [];

                          final selectedEvents = _selectedDay != null 
                              ? _getEventsForDay(interventions, _selectedDay!) 
                              : <Intervention>[];

                          return SingleChildScrollView(
                            padding: EdgeInsets.all(isMobile ? 14 : 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                Text('Aperçu global', style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 20),

                                // KPIs — responsive grid
                                _buildKpiGrid(clients, relances, isMobile, isTablet, vfActive, sdActive),
                                const SizedBox(height: 28),

                                // Calendar + Events — responsive layout
                                isMobile
                                    ? Column(children: [
                                        _buildEventsList(selectedEvents, vfActive, sdActive),
                                        const SizedBox(height: 16),
                                        _buildCalendar(interventions, vfActive, sdActive),
                                      ])
                                    : Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(flex: 1, child: _buildEventsList(selectedEvents, vfActive, sdActive)),
                                          const SizedBox(width: 20),
                                          Expanded(flex: 2, child: _buildCalendar(interventions, vfActive, sdActive)),
                                        ],
                                      ),
                                const SizedBox(height: 28),

                                // Quick actions
                                Text('Actions rapides', style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 14),
                                _buildQuickActions(isMobile),
                              ],
                            ),
                          );
                        },
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

  List<Intervention> _getEventsForDay(List<Intervention> interventions, DateTime day) {
    return interventions.where((i) => isSameDay(i.scheduledDate, day)).toList();
  }

  Widget _buildKpiGrid(List<Client> clients, List<Relance> relances, bool isMobile, bool isTablet, bool vfActive, bool sdActive) {
    final kpis = <_KpiData>[];
    
    if (vfActive) {
      final vfCount = clients.where((c) => c.isVeriflamme && c.actif).length;
      kpis.add(_KpiData('Clients Veriflamme', '$vfCount', AppTheme.veriflammeRed, Icons.local_fire_department, 'assets/images/veriflamme.png'));
    }
    if (sdActive) {
      final sdCount = clients.where((c) => c.isSauvdefib && c.actif).length;
      kpis.add(_KpiData('Clients Sauvdefib', '$sdCount', AppTheme.sauvdefibGreen, Icons.medical_services, 'assets/images/sauvdefib.png'));
    }
    
    final urgentRelances = relances.where((r) => 
        ((r.branche == Branche.veriflamme && vfActive) || (r.branche == Branche.sauvdefib && sdActive)) &&
        r.statut != StatutRelance.cloturee &&
        r.joursRestants <= 30
    ).length;
    
    kpis.add(_KpiData('Relances urgentes', '$urgentRelances', AppTheme.warningOrange, Icons.warning_amber_rounded, null));
    
    if (vfActive && sdActive) {
      final commonCount = clients.where((c) => c.isVeriflamme && c.isSauvdefib && c.actif).length;
      kpis.add(_KpiData('Clients communs', '$commonCount', AppTheme.infoBlue, Icons.people_rounded, null));
    }

    if (isMobile) {
      final screenWidth = MediaQuery.of(context).size.width;
      // Ajustement dynamique du ratio selon la largeur pour éviter les coupures
      final dynamicAspectRatio = screenWidth < 360 ? 1.1 : 1.3;
      
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: dynamicAspectRatio,
        children: kpis.map((k) => _buildKpiCard(k)).toList(),
      );
    }

    return Row(
      children: kpis.map((k) => Expanded(child: Padding(
        padding: EdgeInsets.only(right: k == kpis.last ? 0 : 14),
        child: _buildKpiCard(k),
      ))).toList(),
    );
  }

  Widget _buildKpiCard(_KpiData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Text(
                data.title, 
                style: TextStyle(color: AppTheme.secondaryText, fontWeight: FontWeight.w500, fontSize: 12), 
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              )
            ),
            const SizedBox(width: 4),
            if (data.imageAsset != null)
              Image.asset(data.imageAsset!, height: 18, errorBuilder: (_, __, ___) => Icon(data.icon, color: data.color, size: 18))
            else
              Icon(data.icon, color: data.color, size: 18),
          ]),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              data.value, 
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800, 
                color: data.color
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(List<Intervention> interventions, bool vfActive, bool sdActive) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TableCalendar<Intervention>(
        locale: 'fr_FR',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        startingDayOfWeek: StartingDayOfWeek.monday,
        availableCalendarFormats: const {
          CalendarFormat.month: 'Mois',
        },
        eventLoader: (day) => _getEventsForDay(interventions, day).where((i) => 
          (i.branche == Branche.veriflamme && vfActive) || (i.branche == Branche.sauvdefib && sdActive)
        ).toList(),
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selected, focused) => setState(() {
          _selectedDay = selected;
          _focusedDay = focused;
        }),
        onFormatChanged: (format) => setState(() => _calendarFormat = format),
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        headerStyle: const HeaderStyle(
          formatButtonShowsNext: false,
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          leftChevronIcon: Icon(Icons.chevron_left, size: 20),
          rightChevronIcon: Icon(Icons.chevron_right, size: 20),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          markerSize: 6,
          todayDecoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
          todayTextStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
          selectedDecoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
        ),
        rowHeight: 42,
        daysOfWeekHeight: 20,
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          weekendStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return null;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: events.take(3).map((event) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                width: 5, height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: event.branche == Branche.veriflamme ? AppTheme.veriflammeRed : AppTheme.sauvdefibGreen,
                ),
              )).toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventsList(List<Intervention> events, bool vfActive, bool sdActive) {
    final filteredEvents = events.where((e) => (e.branche == Branche.veriflamme && vfActive) || (e.branche == Branche.sauvdefib && sdActive)).toList();
    
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.event_rounded, size: 20, color: AppTheme.primaryText),
            const SizedBox(width: 8),
            Text('Interventions du jour', style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 14),
          if (filteredEvents.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text('Aucune intervention planifiée.', style: TextStyle(color: AppTheme.secondaryText, fontSize: 13))),
            ),
          ...filteredEvents.map((event) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: event.branche.lightColor,
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: event.branche.color, width: 4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${event.typeIntervention.label} - ${event.technicienNom}', 
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                ),
                const SizedBox(width: 8),
                Icon(event.branche.icon, color: event.branche.color, size: 18),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isMobile) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _quickAction(Icons.person_add_rounded, 'Nouveau client', () => Navigator.pushNamed(context, '/client-form')),
        _quickAction(Icons.add_circle_rounded, 'Nouvelle intervention', () => Navigator.pushNamed(context, '/new-intervention')),
        _quickAction(Icons.people_rounded, 'Voir les clients', () => Navigator.pushNamed(context, '/clients')),
        _quickAction(Icons.notifications_active_rounded, 'Relances urgentes', () => Navigator.pushNamed(context, '/relances')),
      ],
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ]),
      ),
    );
  }
}

class _KpiData {
  final String title, value;
  final Color color;
  final IconData icon;
  final String? imageAsset;
  _KpiData(this.title, this.value, this.color, this.icon, this.imageAsset);
}
