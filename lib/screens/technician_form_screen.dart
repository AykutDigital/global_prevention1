import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../utils/password_helper.dart';

class TechnicianFormScreen extends StatefulWidget {
  final Technician? technician;
  const TechnicianFormScreen({super.key, this.technician});

  @override
  State<TechnicianFormScreen> createState() => _TechnicianFormScreenState();
}

class _TechnicianFormScreenState extends State<TechnicianFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  late final TextEditingController _emailController;
  late final TextEditingController _telController;
  late final TextEditingController _passwordController;
  
  String _role = 'technicien';
  bool _isActif = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final t = widget.technician;
    _nomController = TextEditingController(text: t?.nomComplet ?? '');
    _emailController = TextEditingController(text: t?.email ?? '');
    _telController = TextEditingController(text: t?.telephone ?? '');
    // Ne jamais pré-remplir le mot de passe (on ne ré-affiche jamais le hash)
    _passwordController = TextEditingController();
    _role = t?.role ?? 'technicien';
    _isActif = t?.actif ?? true;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    _telController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final rawPassword = _passwordController.text;

    // Déterminer le hash à stocker :
    // - Nouveau technicien : on hash le mot de passe saisi
    // - Modification sans nouveau mdp : on conserve le hash existant
    // - Modification avec nouveau mdp : on hash le nouveau mdp
    String? passwordToStore;
    if (rawPassword.isNotEmpty) {
      passwordToStore = PasswordHelper.hash(rawPassword, email);
    } else if (widget.technician != null) {
      // Conserver l'ancien hash (inchangé)
      passwordToStore = widget.technician!.password;
    }

    try {
      final tech = Technician(
        id: widget.technician?.id ?? '',
        email: email,
        password: passwordToStore,
        nomComplet: _nomController.text.trim(),
        telephone: _telController.text.trim(),
        role: _role,
        actif: _isActif,
        branches: ['veriflamme', 'sauvdefib'],
      );

      if (widget.technician != null) {
        await SupabaseService.instance.updateTechnician(widget.technician!.id, tech);
      } else {
        await SupabaseService.instance.insertTechnician(tech);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enregistré avec succès'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.technician == null ? 'Ajouter un technicien' : 'Modifier le technicien'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nomController,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email / Login *',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),
                  _PasswordField(
                    controller: _passwordController,
                    isEdit: widget.technician != null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _telController,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  const Text('Rôle et Accès', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_outlined)),
                    items: const [
                      DropdownMenuItem(value: 'technicien', child: Text('Technicien')),
                      DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
                    ],
                    onChanged: (v) => setState(() => _role = v!),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Compte actif'),
                    subtitle: const Text('Permet la connexion à l\'application'),
                    value: _isActif,
                    onChanged: (v) => setState(() => _isActif = v),
                    activeColor: AppTheme.infoBlue,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('ENREGISTRER'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Champ mot de passe avec toggle visibilité et indicateur de force
class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final bool isEdit;

  const _PasswordField({required this.controller, required this.isEdit});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: widget.isEdit ? 'Nouveau mot de passe' : 'Mot de passe *',
        prefixIcon: const Icon(Icons.lock_outline),
        helperText: widget.isEdit
            ? 'Laisser vide pour conserver le mot de passe actuel'
            : 'Minimum 6 caractères',
        helperMaxLines: 2,
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
          tooltip: _obscure ? 'Afficher' : 'Masquer',
        ),
      ),
      validator: (v) {
        if (!widget.isEdit && (v == null || v.isEmpty)) {
          return 'Requis pour un nouveau compte';
        }
        if (v != null && v.isNotEmpty && v.length < 6) {
          return 'Minimum 6 caractères';
        }
        return null;
      },
    );
  }
}
