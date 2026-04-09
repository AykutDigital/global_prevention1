import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/platform_adaptive.dart';
import '../services/app_context_service.dart';
import '../services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  
  bool _vfSelected = false;
  bool _sdSelected = false;

  void _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Real login with Supabase
    try {
      final tech = await SupabaseService.instance.login(
        _emailController.text.trim(), 
        _passwordController.text
      );

      if (!mounted) return;

      if (tech != null) {
        // Update global context with selected branches
        if (!_vfSelected && !_sdSelected) {
          AppContextService.instance.setBranches(veriflamme: true, sauvdefib: true);
        } else {
          AppContextService.instance.setBranches(
            veriflamme: _vfSelected, 
            sauvdefib: _sdSelected
          );
        }
        
        Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
      } else {
        setState(() {
          _errorMessage = 'Identifiants incorrects ou compte inactif';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de connexion : $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: SafeArea(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo placeholder
                  Image.asset(
                    'assets/images/global_prevention.png',
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.security,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'GMAO - Espace Technicien',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.veriflammeRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.veriflammeRed.withOpacity(0.5)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.veriflammeRed, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Adresse e-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('SE CONNECTER'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  Text(
                    'Choisissez votre branche (optionnel)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _branchCard(
                          'Veriflamme',
                          'assets/images/veriflamme.png',
                          Icons.local_fire_department,
                          AppTheme.veriflammeRed,
                          _vfSelected,
                          () => setState(() => _vfSelected = !_vfSelected),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _branchCard(
                          'Sauvdefib',
                          'assets/images/sauvdefib.png',
                          Icons.medical_services,
                          AppTheme.sauvdefibGreen,
                          _sdSelected,
                          () => setState(() => _sdSelected = !_sdSelected),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _branchCard(String name, String asset, IconData icon, Color color, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.cardBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    asset,
                    height: 50,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => Icon(icon, color: color, size: 40),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : AppTheme.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
