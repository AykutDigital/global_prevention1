import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_layout.dart';
import '../services/siret_service.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';

class ClientFormScreen extends StatefulWidget {
  const ClientFormScreen({super.key});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isVeriflamme = true;
  bool _isSauvdefib = false;
  String _typeClient = 'PME';
  bool _isSearchingSiret = false;

  // Controllers for auto-fill
  final _codeController = TextEditingController(text: 'GP-2026-0009');
  final _raisonSocialeController = TextEditingController();
  final _siretController = TextEditingController();
  final _nafController = TextEditingController();
  final _tvaController = TextEditingController();
  final _adresseController = TextEditingController();
  final _cpController = TextEditingController();
  final _villeController = TextEditingController();
  final _contactNomController = TextEditingController();
  final _contactTelController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactFonctionController = TextEditingController();
  final _billingEmailController = TextEditingController();
  final _floorController = TextEditingController();
  final _digicodeController = TextEditingController();
  final _gpsController = TextEditingController();
  final _paymentTermsController = TextEditingController(text: '30');
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _raisonSocialeController.dispose();
    _siretController.dispose();
    _nafController.dispose();
    _tvaController.dispose();
    _adresseController.dispose();
    _cpController.dispose();
    _villeController.dispose();
    _contactNomController.dispose();
    _contactTelController.dispose();
    _contactEmailController.dispose();
    _contactFonctionController.dispose();
    _billingEmailController.dispose();
    _floorController.dispose();
    _digicodeController.dispose();
    _gpsController.dispose();
    _paymentTermsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _lookupSiret() async {
    final siret = _siretController.text.replaceAll(' ', '');
    if (siret.length != 14) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un SIRET valide (14 chiffres)')),
      );
      return;
    }

    setState(() => _isSearchingSiret = true);

    final data = await SiretService.fetchCompanyBySiret(siret);

    setState(() => _isSearchingSiret = false);

    if (data != null) {
      setState(() {
        _raisonSocialeController.text = data['raison_sociale'] ?? '';
        _nafController.text = data['code_naf'] ?? '';
        _adresseController.text = data['adresse'] ?? '';
        _cpController.text = data['code_postal'] ?? '';
        _villeController.text = data['ville'] ?? '';
        _tvaController.text = data['tva_intra'] ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Données récupérées avec succès !'),
          backgroundColor: AppTheme.sauvdefibGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SIRET non trouvé ou erreur réseau.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau client'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _handleSave,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Enregistrer'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Code client auto-generated
                  _sectionTitle('Code client'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.tag_rounded),
                      helperText: 'Généré automatiquement — modifiable par admin',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () {
                          _codeController.text = 'GP-2026-${DateTime.now().millisecond.toString().padLeft(4, '0')}';
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 1. Identité Juridique
                  _sectionTitle('Identité Juridique'),
                  const SizedBox(height: 12),
                  isMobile 
                    ? Column(
                        children: [
                          TextFormField(
                            controller: _raisonSocialeController,
                            decoration: const InputDecoration(
                              labelText: 'Raison sociale *',
                              prefixIcon: Icon(Icons.business_rounded),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _typeClient,
                            decoration: const InputDecoration(
                              labelText: 'Type *',
                              prefixIcon: Icon(Icons.category_rounded),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Particulier', child: Text('Particulier')),
                              DropdownMenuItem(value: 'PME', child: Text('PME')),
                              DropdownMenuItem(value: 'Grande entreprise', child: Text('Grande entreprise')),
                              DropdownMenuItem(value: 'Collectivité', child: Text('Collectivité')),
                            ],
                            onChanged: (v) => setState(() => _typeClient = v!),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _raisonSocialeController,
                              decoration: const InputDecoration(
                                labelText: 'Raison sociale *',
                                prefixIcon: Icon(Icons.business_rounded),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _typeClient,
                              decoration: const InputDecoration(
                                labelText: 'Type *',
                                prefixIcon: Icon(Icons.category_rounded),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Particulier', child: Text('Part.')),
                                DropdownMenuItem(value: 'PME', child: Text('PME')),
                                DropdownMenuItem(value: 'Grande entreprise', child: Text('GE')),
                                DropdownMenuItem(value: 'Collectivité', child: Text('Coll.')),
                              ],
                              onChanged: (v) => setState(() => _typeClient = v!),
                            ),
                          ),
                        ],
                      ),
                  const SizedBox(height: 16),
                  isMobile 
                    ? Column(
                        children: [
                          TextFormField(
                            controller: _siretController,
                            decoration: InputDecoration(
                              labelText: 'SIRET',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              suffixIcon: _isSearchingSiret 
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.search_rounded),
                                    onPressed: _lookupSiret,
                                    tooltip: 'Rechercher les infos par SIRET',
                                  ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nafController,
                            decoration: const InputDecoration(
                              labelText: 'Code NAF',
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _siretController,
                              decoration: InputDecoration(
                                labelText: 'SIRET',
                                prefixIcon: const Icon(Icons.badge_outlined),
                                suffixIcon: _isSearchingSiret 
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.search_rounded),
                                      onPressed: _lookupSiret,
                                      tooltip: 'Rechercher les infos par SIRET',
                                    ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _nafController,
                              decoration: const InputDecoration(
                                labelText: 'Code NAF',
                              ),
                            ),
                          ),
                        ],
                      ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _tvaController,
                    decoration: const InputDecoration(
                      labelText: 'TVA Intracommunautaire',
                      prefixIcon: Icon(Icons.account_balance_rounded),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 2. Contact & Facturation
                  _sectionTitle('Contact & Facturation'),
                  const SizedBox(height: 12),
                  isMobile
                    ? Column(
                        children: [
                          TextFormField(
                            controller: _contactNomController,
                            decoration: const InputDecoration(
                              labelText: 'Nom du contact *',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _contactFonctionController,
                            decoration: const InputDecoration(
                              labelText: 'Fonction',
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _contactNomController,
                              decoration: const InputDecoration(
                                labelText: 'Nom du contact *',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _contactFonctionController,
                              decoration: const InputDecoration(
                                labelText: 'Fonction',
                              ),
                            ),
                          ),
                        ],
                      ),
                  const SizedBox(height: 16),
                  isMobile
                      ? Column(
                          children: [
                            TextFormField(
                              controller: _contactTelController,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone *',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _contactEmailController,
                              decoration: const InputDecoration(
                                labelText: 'E-mail principal *',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _contactTelController,
                                decoration: const InputDecoration(
                                  labelText: 'Téléphone *',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _contactEmailController,
                                decoration: const InputDecoration(
                                  labelText: 'E-mail principal *',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _billingEmailController,
                    decoration: const InputDecoration(
                      labelText: 'E-mail de facturation (si différent)',
                      prefixIcon: Icon(Icons.receipt_long_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 32),

                  // 3. Site & Logistique
                  _sectionTitle('Site & Logistique'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _adresseController,
                    decoration: const InputDecoration(
                      labelText: 'Adresse d\'intervention *',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: _cpController,
                          decoration: const InputDecoration(labelText: 'CP *'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _villeController,
                          decoration: const InputDecoration(labelText: 'Ville *'),
                          validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  isMobile 
                    ? Column(
                        children: [
                          TextFormField(
                            controller: _floorController,
                            decoration: const InputDecoration(
                              labelText: 'Étage / Porte',
                              prefixIcon: Icon(Icons.layers_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _digicodeController,
                            decoration: const InputDecoration(
                              labelText: 'Digicode',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _floorController,
                              decoration: const InputDecoration(
                                labelText: 'Étage / Porte',
                                prefixIcon: Icon(Icons.layers_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _digicodeController,
                              decoration: const InputDecoration(
                                labelText: 'Digicode',
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _gpsController,
                    decoration: const InputDecoration(
                      labelText: 'Coordonnées GPS (ex: 48.8566, 2.3522)',
                      prefixIcon: Icon(Icons.gps_fixed_rounded),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 4. Administration & Branches
                  _sectionTitle('Administration'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _paymentTermsController,
                    decoration: const InputDecoration(
                      labelText: 'Délai de paiement (jours)',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('Branches actives'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.cardDecoration(),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: _isVeriflamme,
                          onChanged: (v) => setState(() => _isVeriflamme = v!),
                          title: const Row(
                            children: [
                              Icon(Icons.local_fire_department, color: AppTheme.veriflammeRed, size: 20),
                              SizedBox(width: 8),
                              Text('Veriflamme', style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          subtitle: const Text('Sécurité incendie'),
                          activeColor: AppTheme.veriflammeRed,
                          controlAffinity: ListTileControlAffinity.trailing,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const Divider(),
                        CheckboxListTile(
                          value: _isSauvdefib,
                          onChanged: (v) => setState(() => _isSauvdefib = v!),
                          title: const Row(
                            children: [
                              Icon(Icons.medical_services, color: AppTheme.sauvdefibGreen, size: 20),
                              SizedBox(width: 8),
                              Text('Sauvdefib', style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          subtitle: const Text('Défibrillateurs'),
                          activeColor: AppTheme.sauvdefibGreen,
                          controlAffinity: ListTileControlAffinity.trailing,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Notes
                  _sectionTitle('Instructions & Notes'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Consignes de sécurité ou notes internes',
                      prefixIcon: Icon(Icons.sticky_note_2_outlined),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 40),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryText,
      ),
    );
  }

  void _handleSave() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        // Create new client object
        final newClient = Client(
          clientId: '', // Supabase will generate a UUID if we skip it in toJson or let it handle it
          codeClient: _codeController.text.isNotEmpty 
              ? _codeController.text 
              : 'GP-${DateTime.now().year}-${DateTime.now().millisecond}',
          raisonSociale: _raisonSocialeController.text,
          typeClient: _getTypeClientEnum(_typeClient),
          adresse: _adresseController.text,
          codePostal: _cpController.text,
          ville: _villeController.text,
          contactNom: _contactNomController.text,
          contactPosition: _contactFonctionController.text,
          contactTel: _contactTelController.text,
          contactEmail: _contactEmailController.text,
          isVeriflamme: _isVeriflamme,
          isSauvdefib: _isSauvdefib,
          dateCreation: DateTime.now(),
          siret: _siretController.text,
          codeNaf: _nafController.text,
          tvaIntra: _tvaController.text,
          billingEmail: _billingEmailController.text.isNotEmpty ? _billingEmailController.text : null,
          floor: _floorController.text.isNotEmpty ? _floorController.text : null,
          accessInstructions: _digicodeController.text.isNotEmpty ? _digicodeController.text : null,
          gpsCoordinates: _gpsController.text.isNotEmpty ? _gpsController.text : null,
          paymentTerms: int.tryParse(_paymentTermsController.text) ?? 30,
          noteInterne: _notesController.text.isNotEmpty ? _notesController.text : null,
        );

        // Save to Supabase
        await SupabaseService.instance.insertClient(newClient);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client enregistré avec succès dans le Cloud !'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.sauvdefibGreen,
          ),
        );
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  TypeClient _getTypeClientEnum(String label) {
    switch (label) {
      case 'Particulier': return TypeClient.particulier;
      case 'Grande entreprise': return TypeClient.grandeEntreprise;
      case 'Collectivité': return TypeClient.collectivite;
      default: return TypeClient.pme;
    }
  }
}
