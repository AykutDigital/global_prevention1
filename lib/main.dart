import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/client_form_screen.dart';
import 'screens/interventions_screen.dart';
import 'screens/new_intervention_screen.dart';
import 'screens/risk_analysis_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/relances_screen.dart';
import 'screens/admin_screen.dart';
import 'theme/app_theme.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Important: Initialize Supabase before the app starts
  await Supabase.initialize(
    url: 'https://yyetfxcqnmextzqktodu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl5ZXRmeGNxbm1leHR6cWt0b2R1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2NTk4NTgsImV4cCI6MjA5MTIzNTg1OH0.e2c3fhiE_6lhZP7QUToNT6F_Y4mdZfDna_x9EB2ZQyY',
  );

  await initializeDateFormatting('fr_FR', null).catchError((_) {});
  
  // Seed database if empty with mock data
  await SupabaseService.instance.seedIfEmpty();
  
  runApp(const GlobalPreventionApp());
}

class GlobalPreventionApp extends StatelessWidget {
  const GlobalPreventionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Global Prevention — GMAO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
      ],
      locale: const Locale('fr', 'FR'),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/clients': (_) => const ClientsScreen(),
        '/client-form': (_) => const ClientFormScreen(),
        '/interventions': (_) => const InterventionsScreen(),
        '/new-intervention': (_) => const NewInterventionScreen(),
        '/risk-analysis': (_) => const RiskAnalysisScreen(),
        '/reports': (_) => const ReportsScreen(),
        '/relances': (_) => const RelancesScreen(),
        '/admin': (_) => const AdminScreen(),
      },
    );
  }
}
