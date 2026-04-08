import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/responsive_layout.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<_CalEvent>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    final today = DateTime.now();
    _events[DateTime(today.year, today.month, today.day)] = [
      _CalEvent('Maintenance Extincteurs — Hôtel Le Méridien', true),
      _CalEvent('Vérification DAE — Clinique Sainte-Anne', false),
    ];
    _events[DateTime(today.year, today.month, today.day).add(const Duration(days: 2))] = [
      _CalEvent('Installation RIA — Mairie Boulogne', true),
    ];
    _events[DateTime(today.year, today.month, today.day).subtract(const Duration(days: 1))] = [
      _CalEvent('Relance Annuelle Defib — Lycée Victor Hugo', false),
    ];
    _events[DateTime(today.year, today.month, today.day).add(const Duration(days: 5))] = [
      _CalEvent('Maintenance Colonnes Sèches — Les 4 Temps', true),
    ];
    _events[DateTime(today.year, today.month, today.day).add(const Duration(days: 7))] = [
      _CalEvent('Maintenance Extincteurs — Crèche Petits Loups', true),
    ];
  }

  List<_CalEvent> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _selectedDay != null ? _getEventsForDay(_selectedDay!) : <_CalEvent>[];
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 14 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text('Aperçu global', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),

            // KPIs — responsive grid
            _buildKpiGrid(isMobile, isTablet),
            const SizedBox(height: 28),

            // Calendar + Events — responsive layout
            isMobile
                ? Column(children: [
                    _buildCalendar(),
                    const SizedBox(height: 16),
                    _buildEventsList(selectedEvents),
                  ])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildCalendar()),
                      const SizedBox(width: 20),
                      Expanded(flex: 1, child: _buildEventsList(selectedEvents)),
                    ],
                  ),
            const SizedBox(height: 28),

            // Quick actions
            Text('Actions rapides', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            _buildQuickActions(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiGrid(bool isMobile, bool isTablet) {
    final kpis = [
      _KpiData('Clients Veriflamme', '${MockData.clientsVeriflammeCount}', AppTheme.veriflammeRed, Icons.local_fire_department, 'assets/images/veriflamme.png'),
      _KpiData('Clients Sauvdefib', '${MockData.clientsSauvdefibCount}', AppTheme.sauvdefibGreen, Icons.medical_services, 'assets/images/sauvdefib.png'),
      _KpiData('Relances urgentes', '${MockData.relancesUrgentes.length}', AppTheme.warningOrange, Icons.warning_amber_rounded, null),
      _KpiData('Clients communs', '${MockData.clientsCommunsCount}', AppTheme.infoBlue, Icons.people_rounded, null),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3, // Augmenté pour laisser plus de place verticale sur mobile
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
      padding: const EdgeInsets.all(16), // Légèrement réduit pour gagner de la place
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
                fontSize: 24, // Réduit de 30 à 24 pour éviter les débordements verticaux
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

  Widget _buildCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TableCalendar<_CalEvent>(
        locale: 'fr_FR',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        eventLoader: _getEventsForDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selected, focused) => setState(() {
          _selectedDay = selected;
          _focusedDay = focused;
        }),
        onFormatChanged: (format) => setState(() => _calendarFormat = format),
        headerStyle: const HeaderStyle(
          formatButtonShowsNext: false,
          titleCentered: true,
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.15), shape: BoxShape.circle),
          todayTextStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700),
          selectedDecoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
          markerSize: 7,
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return const SizedBox();
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: events.take(3).map((event) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: event.isVeriflamme ? AppTheme.veriflammeRed : AppTheme.sauvdefibGreen,
                ),
              )).toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventsList(List<_CalEvent> events) {
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
          if (events.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text('Aucune intervention planifiée.', style: TextStyle(color: AppTheme.secondaryText, fontSize: 13))),
            ),
          ...events.map((event) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: event.isVeriflamme ? AppTheme.veriflammeRedLight : AppTheme.sauvdefibGreenLight,
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: event.isVeriflamme ? AppTheme.veriflammeRed : AppTheme.sauvdefibGreen, width: 4)),
            ),
            child: Row(children: [
              Expanded(child: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
              Icon(event.isVeriflamme ? Icons.local_fire_department : Icons.medical_services,
                color: event.isVeriflamme ? AppTheme.veriflammeRed : AppTheme.sauvdefibGreen, size: 18),
            ]),
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
        _quickAction(Icons.person_add_rounded, 'Nouveau client', () async {
          final result = await Navigator.pushNamed(context, '/client-form');
          if (result == true && mounted) {
            // Dashboard doesn't show list, but we can show a refresh snackbar or similar if needed
            // For now, just ensure it doesn't crash
          }
        }),
        _quickAction(Icons.add_circle_rounded, 'Nouvelle intervention', () => Navigator.pushNamed(context, '/new-intervention')),
        _quickAction(Icons.people_rounded, 'Voir les clients', () => Navigator.pushReplacementNamed(context, '/clients')),
        _quickAction(Icons.notifications_active_rounded, 'Relances urgentes', () => Navigator.pushReplacementNamed(context, '/relances')),
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

class _CalEvent {
  final String title;
  final bool isVeriflamme;
  _CalEvent(this.title, this.isVeriflamme);
}

class _KpiData {
  final String title, value;
  final Color color;
  final IconData icon;
  final String? imageAsset;
  _KpiData(this.title, this.value, this.color, this.icon, this.imageAsset);
}
