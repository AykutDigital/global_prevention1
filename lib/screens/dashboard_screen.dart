import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class Event {
  final String title;
  final bool isVeriflamme;

  Event(this.title, this.isVeriflamme);
}

class _DashboardScreenState extends State<DashboardScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Mock data for agenda
  final Map<DateTime, List<Event>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    
    // Generate some mock events
    final today = DateTime.now();
    _events[DateTime(today.year, today.month, aujourdHuiPlus(0))] = [
      Event('Maintenance Extincteurs', true),
      Event('Vérification DAE', false)
    ];
    _events[DateTime(today.year, today.month, aujourdHuiPlus(2))] = [
      Event('Installation RIA', true)
    ];
    _events[DateTime(today.year, today.month, aujourdHuiMoins(1))] = [
      Event('Relance Annuelle Defib', false)
    ];
  }

  int aujourdHuiMoins(int days) {
    var today = DateTime.now();
    return today.subtract(Duration(days: days)).day;
  }

  int aujourdHuiPlus(int days) {
    var today = DateTime.now();
    return today.add(Duration(days: days)).day;
  }

  List<Event> _getEventsForDay(DateTime day) {
    // Normalize time to midnight
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar menu (Mock)
          Container(
            width: 250,
            color: AppTheme.surface,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildMenuItem(Icons.dashboard, 'Tableau de bord', true),
                _buildMenuItem(Icons.people, 'Clients', false),
                _buildMenuItem(Icons.build, 'Interventions', false),
                _buildMenuItem(Icons.description, 'Rapports', false),
                _buildMenuItem(Icons.notifications_active, 'Relances', false),
                const Divider(),
                _buildMenuItem(Icons.settings, 'Administration', false),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aperçu global',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  // KPI Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Clients Actifs Veriflamme',
                          value: '142',
                          color: AppTheme.veriflammeRed,
                          icon: Icons.local_fire_department,
                          imageAsset: 'assets/images/veriflamme.png',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Clients Actifs Sauvdefib',
                          value: '89',
                          color: AppTheme.sauvdefibGreen,
                          icon: Icons.medical_services,
                          imageAsset: 'assets/images/sauvdefib.png',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Relances Urgentes',
                          value: '12',
                          color: Colors.orange,
                          icon: Icons.warning_amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Calendar and Events Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calendar
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: TableCalendar<Event>(
                            firstDay: DateTime.utc(2020, 10, 16),
                            lastDay: DateTime.utc(2030, 3, 14),
                            focusedDay: _focusedDay,
                            calendarFormat: _calendarFormat,
                            eventLoader: _getEventsForDay,
                            selectedDayPredicate: (day) {
                              return isSameDay(_selectedDay, day);
                            },
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            onFormatChanged: (format) {
                              setState(() {
                                _calendarFormat = format;
                              });
                            },
                            calendarStyle: const CalendarStyle(
                              markerSize: 8,
                            ),
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, date, events) {
                                if (events.isEmpty) return const SizedBox();
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: events.map((event) {
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: event.isVeriflamme
                                            ? AppTheme.veriflammeRed
                                            : AppTheme.sauvdefibGreen,
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Events List for selected day
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Interventions du jour',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              if (selectedEvents.isEmpty)
                                const Text('Aucune intervention planifiée pour ce jour.'),
                              ...selectedEvents.map((event) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: event.isVeriflamme
                                      ? AppTheme.veriflammeRed.withOpacity(0.1)
                                      : AppTheme.sauvdefibGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border(
                                    left: BorderSide(
                                      color: event.isVeriflamme
                                          ? AppTheme.veriflammeRed
                                          : AppTheme.sauvdefibGreen,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        event.title,
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Icon(
                                      event.isVeriflamme ? Icons.local_fire_department : Icons.medical_services,
                                      color: event.isVeriflamme
                                          ? AppTheme.veriflammeRed
                                          : AppTheme.sauvdefibGreen,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle Intervention'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, bool isSelected) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : AppTheme.secondaryText),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.primary : AppTheme.secondaryText,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      onTap: () {},
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    String? imageAsset,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border(bottom: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.secondaryText,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (imageAsset != null)
                Image.asset(
                  imageAsset,
                  height: 24,
                  errorBuilder: (context, error, stackTrace) => Icon(icon, color: color, size: 20),
                )
              else
                Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}
