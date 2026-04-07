import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize locale formatting for calendar if necessary (often used in table_calendar)
  await initializeDateFormatting('fr_FR', null).catchError((_) {});
  runApp(const GlobalPreventionApp());
}

class GlobalPreventionApp extends StatelessWidget {
  const GlobalPreventionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Global Prevention',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
