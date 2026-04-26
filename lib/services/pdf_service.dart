import 'dart:io';
import 'dart:convert';
import 'dart:math' show pi;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../services/supabase_service.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';

class _ArboRow {
  final Node node;
  final int depth;
  final InterventionAction? action;
  const _ArboRow({required this.node, required this.depth, this.action});
}

class PdfService {
  static Future<Uint8List> buildReportBytes({
    required Client client,
    required Intervention intervention,
    required Rapport rapport,
    required List<Equipment> equipments,
    RiskAnalysis? riskAnalysis,
    List<InterventionAction>? extraActions,
    Uint8List? logoBytes,
    Uint8List? signatureClient,
    Uint8List? signatureTechnicien,
    List<File>? interventionPhotos,
    bool isPreview = false,
  }) async {
    final pdf = pw.Document();
    final displayDate = intervention.actualDate ?? intervention.scheduledDate;
    final dateStr = DateFormat('dd/MM/yyyy').format(displayDate);
    
    // UI Colors from template
    final headerBlue = PdfColor.fromInt(0xFFB6D0E2);
    final pdfLightBlue = PdfColor.fromInt(0xFFE8F4F8);
    final primaryColor = PdfColor.fromInt(intervention.branche == Branche.veriflamme ? 0xFFD32F2F : 0xFF2E7D32);

    final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    // Override signatures to null if preview mode
    if (isPreview) {
      signatureClient = null;
      signatureTechnicien = null;
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
        ),
        build: (pw.Context context) {
          return [
            // Ligne 1 : Date (gauche) + Logo (droite) — légèrement plus haut que le titre
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Date : $dateStr', style: const pw.TextStyle(fontSize: 10)),
                if (logo != null)
                  pw.Container(width: 130, child: pw.Image(logo))
                else
                  pw.Text('GLOBAL PREVENTION', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              ],
            ),
            pw.SizedBox(height: 6),

            // Ligne 2 : Titre + N° centré (en dessous de la date et du logo)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('RAPPORT DE VÉRIFICATION', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
                      child: pw.Row(
                        children: [
                          pw.Text('N°', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(width: 20),
                          pw.Text(rapport.numeroRapport, style: const pw.TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),

            // Top Info Boxes: Intervention and Billing
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    height: 110,
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: headerBlue, width: 1.5)),
                    child: pw.Column(
                      children: [
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(2),
                          color: headerBlue,
                          child: pw.Text('Lieu d\'Intervention', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue900)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _infoRow('Nom du client :', client.raisonSociale),
                              _infoRow('Adresse :', client.adresse),
                              _infoRow('Tél :', client.contactTel),
                              _infoRow('Email :', client.contactEmail),
                              _infoRow('Contact :', client.contactNom),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Container(
                    height: 110,
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: headerBlue, width: 1.5)),
                    child: pw.Column(
                      children: [
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(2),
                          color: headerBlue,
                          child: pw.Text('Lieu de Facturation', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue900)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _infoRow('Nom du client :', client.raisonSociale),
                              _infoRow('Adresse :', client.billingAddress ?? client.adresse),
                              _infoRow('Tél :', client.contactTel),
                              _infoRow('Email :', client.billingEmail ?? client.contactEmail),
                              _infoRow('Contact :', client.contactNom),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Bottom Info Box: Activity, Risks, Surface...
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: headerBlue, width: 1.5)),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _infoRow('Activité :', intervention.activiteSite ?? client.activite ?? '-'),
                          _infoRow('Analyse de risque :', _parseRiskAnalysis(riskAnalysis, intervention.risquesSite)),
                        ],
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _infoRow('Surface :', '${intervention.surfaceM2 ?? "-"} m²'),
                          _infoRow('Registre de sécurité :', intervention.registreSecurite ? 'Présent' : 'Absent'),
                          _infoRow('Technicien :', intervention.technicienNom),
                          _infoRow('Date d\'intervention :', DateFormat('dd/MM/yyyy').format(intervention.dateIntervention)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 15),

            if (intervention.typeIntervention == TypeIntervention.preVisite) ...[
              pw.SizedBox(height: 10),
              pw.Text('CAHIER DES CHARGES / PRÉ-VISITE', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: headerBlue)),
              pw.SizedBox(height: 10),
              ...List<pw.Widget>.from((jsonDecode(intervention.arborescenceJson ?? '[]') as List).map((zone) {
                final lignes = (zone['lignes'] as List? ?? []);
                double zoneTotal = 0;
                for (var l in lignes) {
                    zoneTotal += ((l['quantite'] as num?) ?? 1) * ((l['prixUnitaire'] as num?) ?? 0.0);
                }
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        color: headerBlue,
                        width: double.infinity,
                        child: pw.Text('${zone["nom"]}  |  Total estimé: ${zoneTotal.toStringAsFixed(2)} €', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      if (lignes.isEmpty)
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Aucun équipement défini.', style: const pw.TextStyle(fontSize: 9)))
                      else
                        pw.Table(
                          border: pw.TableBorder.all(color: headerBlue, width: 0.5),
                          columnWidths: {
                            0: const pw.FixedColumnWidth(40),
                            1: const pw.FlexColumnWidth(4),
                            2: const pw.FixedColumnWidth(60),
                            3: const pw.FixedColumnWidth(60),
                          },
                          children: [
                            pw.TableRow(
                              decoration: pw.BoxDecoration(color: pdfLightBlue),
                              children: [
                                _cell('Qté', center: true, bold: true),
                                _cell('Description du besoin', bold: true),
                                _cell('Prix U. (€)', center: true, bold: true),
                                _cell('Total (€)', center: true, bold: true),
                              ]
                            ),
                            ...lignes.map((l) {
                              final qty = (l['quantite'] as num?) ?? 1;
                              final px = ((l['prixUnitaire'] as num?) ?? 0.0).toDouble();
                              return pw.TableRow(
                                children: [
                                  _cell('$qty', center: true),
                                  _cell('${l["description"]}'),
                                  _cell('${px.toStringAsFixed(2)}', center: true),
                                  _cell('${(qty * px).toStringAsFixed(2)}', center: true),
                                ]
                              );
                            }),
                          ]
                        )
                    ]
                  )
                );
              })),
            ] else ...[
              // Type Selection
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  _checkbox('Vérification', intervention.typeIntervention == TypeIntervention.maintenance),
                  pw.SizedBox(width: 25),
                  _checkbox('Implantation', intervention.typeIntervention == TypeIntervention.installation),
                  pw.SizedBox(width: 25),
                  _checkbox('Dépannage', intervention.typeIntervention == TypeIntervention.depannage),
                ],
              ),
              pw.SizedBox(height: 15),

              // 8-Column Technical Table
              pw.Table(
                border: pw.TableBorder.all(color: headerBlue, width: 1),
                columnWidths: {
                  0: const pw.FixedColumnWidth(25),  // N°
                  1: const pw.FlexColumnWidth(2.5), // Implantation
                  2: const pw.FixedColumnWidth(40),  // Niveau
                  3: const pw.FlexColumnWidth(3),   // Type
                  4: const pw.FixedColumnWidth(40),  // Année
                  5: const pw.FlexColumnWidth(2),   // Marque
                  6: const pw.FixedColumnWidth(35),  // État
                  7: const pw.FlexColumnWidth(3.5), // Observation
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: headerBlue),
                    children: [
                      _cell('N°', bold: true, fontSize: 8, center: true),
                      _cell('Implantation', bold: true, fontSize: 8, center: true),
                      _cell('Niveau', bold: true, fontSize: 8, center: true),
                      _cell('Type d\'extincteur', bold: true, fontSize: 8, center: true),
                      _cell('Année', bold: true, fontSize: 8, center: true),
                      _cell('Marque', bold: true, fontSize: 8, center: true),
                      _cell('État', bold: true, fontSize: 8, center: true),
                      _cell('Observation', bold: true, fontSize: 8, center: true),
                    ],
                  ),
                  // Data
                  ...rapport.equipmentChecks.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final check = entry.value;
                    final eq = equipments.firstWhere(
                      (e) => e.id == check.equipmentId, 
                      orElse: () => Equipment(id: '', clientId: '', branche: intervention.branche, type: '-')
                    );
                    
                    return pw.TableRow(
                      children: [
                        _cell('$idx', fontSize: 8, center: true),
                        _cell(eq.location ?? '-', fontSize: 8),
                        _cell(eq.niveau ?? '-', fontSize: 8, center: true),
                        _cell('${eq.type} ${eq.capacity ?? ""}', fontSize: 8),
                        _cell(eq.manufactureYear?.toString() ?? '-', fontSize: 8, center: true),
                        _cell(eq.brand ?? '-', fontSize: 8),
                        _cell(check.status.label, fontSize: 8, center: true),
                        _cell(check.observations ?? '-', fontSize: 7),
                      ],
                    );
                  }),
                ],
              ),
              
              if (extraActions != null && extraActions.isNotEmpty) ...[
                pw.SizedBox(height: 15),
                pw.Text('TRAVAUX COMPLÉMENTAIRES & PIÈCES', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                pw.SizedBox(height: 5),
                pw.Table(
                  border: pw.TableBorder.all(color: headerBlue, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: pdfLightBlue),
                      children: [
                        _cell('Description de la prestation / Pièce', bold: true, fontSize: 8),
                        _cell('Impact Prix (€)', bold: true, fontSize: 8, center: true),
                      ],
                    ),
                    ...extraActions.map((action) => pw.TableRow(
                      children: [
                        _cell(action.status, fontSize: 8),
                        _cell('${action.priceImpact.toStringAsFixed(2)} €', fontSize: 8, center: true),
                      ],
                    )),
                  ],
                ),
              ],
              
              // Legend
              pw.SizedBox(height: 5),
              pw.RichText(
                text: pw.TextSpan(
                  style: const pw.TextStyle(fontSize: 8),
                  children: [
                    pw.TextSpan(text: 'Légende : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: 'V Vérifié conforme / NV Non vérifié / MS Mise en service / R Réformé à remplacer / HS Hors service / P Préconisation'),
                  ],
                ),
              ),
            ],
            pw.SizedBox(height: 25),

            // Preview watermark text banner
            if (isPreview)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                margin: const pw.EdgeInsets.only(bottom: 15),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFFFF3E0),
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFF57C00), width: 1.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('⚠ PRÉVISUALISATION — DOCUMENT SANS VALEUR — SIGNATURE À VENIR', 
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFFF57C00)),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),

            // Ligne unique : [Signatures gauche] [Logo vertical] [Carré adresse] — alignés sur la même ligne
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [

                // GAUCHE (étendu) : signature client + signature technicien côte à côte
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Signature client
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('SIGNATURE DU CLIENT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.SizedBox(height: 8),
                          if (signatureClient != null)
                            pw.Image(pw.MemoryImage(signatureClient!), width: 130, height: 60, fit: pw.BoxFit.contain)
                          else if (isPreview)
                            pw.Container(
                              width: 130, height: 60,
                              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300, style: pw.BorderStyle.dashed), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                              child: pw.Text('Signature client', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400), textAlign: pw.TextAlign.center),
                            ),
                        ],
                      ),
                      pw.SizedBox(width: 16),
                      // Signature technicien
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('SIGNATURE DU TECHNICIEN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.SizedBox(height: 8),
                          if (signatureTechnicien != null)
                            pw.Image(pw.MemoryImage(signatureTechnicien), width: 130, height: 60, fit: pw.BoxFit.contain)
                          else if (isPreview)
                            pw.Container(
                              width: 130, height: 60,
                              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300, style: pw.BorderStyle.dashed), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                              child: pw.Text('Signature\ntechnicien', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400), textAlign: pw.TextAlign.center),
                            ),
                          pw.SizedBox(height: 4),
                          pw.Text(intervention.technicienNom, style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Logo vertical, juste à gauche du badge adresse
                if (logo != null) ...[
                  pw.SizedBox(width: 4),
                  pw.Transform.rotate(
                    angle: -pi / 2,
                    child: pw.Image(logo, width: 65, height: 22, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(width: 14),
                ],

                // Badge adresse sans bordure, avec icônes colorées
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Adresse
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('◉  ', style: pw.TextStyle(fontSize: 9, color: primaryColor)),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('20 Av. Des Frères Montgolfier', style: const pw.TextStyle(fontSize: 8)),
                            pw.Text('Espace Mi-Plaine 1er Étage', style: const pw.TextStyle(fontSize: 8)),
                            pw.Text('69680 Chassieu', style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    // Téléphone
                    pw.Row(
                      children: [
                        pw.Text('✆  ', style: pw.TextStyle(fontSize: 9, color: primaryColor)),
                        pw.Text('04 37 54 55 99', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    // Site web
                    pw.Row(
                      children: [
                        pw.Text('✱  ', style: pw.TextStyle(fontSize: 9, color: primaryColor)),
                        pw.Text(
                          intervention.branche == Branche.veriflamme ? 'veriflamme.fr' : 'sauvdefib.fr',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    // Email
                    pw.Row(
                      children: [
                        pw.Text('✉  ', style: pw.TextStyle(fontSize: 9, color: primaryColor)),
                        pw.Text(
                          intervention.branche == Branche.veriflamme ? 'contact@veriflamme.fr' : 'contact@sauvdefib.fr',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // Photos : toujours sur la page 2
            if (interventionPhotos != null && interventionPhotos.isNotEmpty) ...[
              pw.NewPage(),
              pw.Text('PHOTOS DE L\'INTERVENTION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: primaryColor)),
              pw.SizedBox(height: 10),
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: interventionPhotos.map((file) {
                  return pw.Container(
                    width: 240,
                    height: 180,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Image(
                      pw.MemoryImage(file.readAsBytesSync()),
                      fit: pw.BoxFit.cover,
                    ),
                  );
                }).toList(),
              ),
            ],
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text('Page ${context.pageNumber} sur ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _checkbox(String label, bool checked) {
    return pw.Row(
      children: [
        pw.Container(
          width: 10,
          height: 10,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black),
          ),
          child: checked ? pw.Center(child: pw.Text('X', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))) : null,
        ),
        pw.SizedBox(width: 5),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  /// Parse le JSON d'analyse de risque et retourne un résumé lisible
  static String _parseRiskSummary(String? risquesSite) {
    if (risquesSite == null || risquesSite.isEmpty) return '-';
    try {
      final data = jsonDecode(risquesSite) as Map<String, dynamic>;
      // Si c'est un JSON d'analyse de risque structuré
      if (data.containsKey('answers')) {
        final answers = data['answers'] as Map<String, dynamic>? ?? {};
        final decision = data['decision'] as bool?;
        final motif = data['motif'] as String? ?? '';
        final total = answers.length;
        final answered = answers.values.where((v) => v != null).length;
        final nonCount = answers.values.where((v) => v == false).length;

        String summary = 'Analyse complétée ($answered/$total questions)';
        if (nonCount > 0) summary += ' — $nonCount réponse(s) NON';
        if (decision != null) {
          summary += '\nDécision : ${decision ? "✓ Intervention autorisée" : "✗ Intervention refusée/reportée"}';
        }
        if (motif.isNotEmpty) summary += '\nMotif : $motif';
        return summary;
      }
    } catch (_) {}
    return risquesSite;
  }

  static String _parseRiskAnalysis(RiskAnalysis? analysis, String? oldRisques) {
    if (analysis == null) return _parseRiskSummary(oldRisques);
    
    final count = analysis.responses.length;
    final nonCount = analysis.responses.values.where((v) => v == false).length;
    
    String summary = 'Analyse signée ($count questions)';
    if (nonCount > 0) summary += ' — $nonCount danger(s) identifié(s)';
    if (analysis.isBlocking) summary += '\n⚠ INTERVENTION BLOQUÉE PAR SÉCURITÉ';
    if (analysis.observations != null && analysis.observations!.isNotEmpty) {
      summary += '\nObservations : ${analysis.observations}';
    }
    return summary;
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 8),
          children: [
            pw.TextSpan(text: label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: ' $value'),
          ],
        ),
      ),
    );
  }

  static Future<void> printOrShare(File file) async {
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);
  }

  static Future<void> shareFile(File file, String subject, {String? text}) async {
    await Share.shareXFiles([XFile(file.path)], subject: subject, text: text);
  }

  static Future<void> sendEmailLink(String email, String pdfUrl, String rapportNum) async {
    final Uri params = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Rapport d\'intervention $rapportNum&body=Bonjour,\n\nVeuillez trouver ci-joint le lien vers votre rapport d\'intervention :\n$pdfUrl\n\nCordialement,\nL\'équipe Global Prevention',
    );
    if (await canLaunchUrl(params)) {
      await launchUrl(params);
    }
  }

  static Future<File> generateInterventionReport({
    required Client client,
    required Intervention intervention,
    required Rapport rapport,
    required List<Equipment> equipments,
    RiskAnalysis? riskAnalysis,
    List<InterventionAction>? extraActions,
    Uint8List? signatureClient,
    Uint8List? signatureTechnicien,
    List<File>? interventionPhotos,
    bool isPreview = false,
  }) async {
    // Load branch logo
    Uint8List? logoBytes;
    try {
      final logoData = await rootBundle.load(intervention.branche == Branche.veriflamme ? 'assets/images/veriflamme.png' : 'assets/images/sauvdefib.png');
      logoBytes = logoData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error loading logo: $e');
    }

    final bytes = await buildReportBytes(
      client: client,
      intervention: intervention,
      rapport: rapport,
      equipments: equipments,
      riskAnalysis: riskAnalysis,
      extraActions: extraActions,
      logoBytes: logoBytes,
      signatureClient: signatureClient,
      signatureTechnicien: signatureTechnicien,
      interventionPhotos: interventionPhotos,
      isPreview: isPreview,
    );
    
    final output = await getTemporaryDirectory();
    final prefix = isPreview ? 'preview_' : 'rapport_';
    final file = File("${output.path}/${prefix}${rapport.numeroRapport}.pdf");
    await file.writeAsBytes(bytes);
    return file;
  }

  // ─── RAPPORT ARBORESCENCE ─────────────────────────────────────────────────

  static Future<Uint8List> buildArborescenceBytes({
    required String raisonSociale,
    required List<Node> nodes,
    List<InterventionAction> actions = const [],
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final primaryColor = PdfColor.fromInt(0xFFD32F2F);
    final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    // Build tree map
    final Map<String, List<Node>> tree = {};
    for (final node in nodes) {
      final key = node.parentId ?? 'root';
      tree.putIfAbsent(key, () => []).add(node);
    }
    for (final list in tree.values) {
      list.sort((a, b) => a.label.compareTo(b.label));
    }

    // Flatten tree to ordered rows for PDF
    final rows = <_ArboRow>[];
    void walk(String parentId, int depth) {
      for (final node in tree[parentId] ?? []) {
        final action = actions.where((a) => a.nodeId == node.id).firstOrNull;
        rows.add(_ArboRow(node: node, depth: depth, action: action));
        walk(node.id, depth + 1);
      }
    }
    walk('root', 0);

    // Status colors
    PdfColor _statusColor(String label) {
      switch (label) {
        case 'V':  return PdfColor.fromInt(0xFF4CAF50);
        case 'NV': return PdfColors.grey600;
        case 'MS': return PdfColor.fromInt(0xFF2196F3);
        case 'R':  return PdfColor.fromInt(0xFFFF9800);
        case 'HS': return PdfColor.fromInt(0xFFF44336);
        case 'P':  return PdfColor.fromInt(0xFF9C27B0);
        default:   return PdfColors.grey600;
      }
    }

    String _typePrefix(String type) {
      switch (type) {
        case 'building':  return '🏢 ';
        case 'level':     return '📐 ';
        case 'zone':      return '⬜ ';
        case 'room':      return '🚪 ';
        case 'equipment': return '🔧 ';
        default: return '';
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
        ),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Date : $dateStr', style: const pw.TextStyle(fontSize: 10)),
                if (logo != null)
                  pw.Container(width: 120, child: pw.Image(logo))
                else
                  pw.Text('GLOBAL PREVENTION', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('ARBORESCENCE', style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  pw.Text(raisonSociale, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1, color: primaryColor),
            pw.SizedBox(height: 8),
            if (context.pageNumber > 1) pw.SizedBox.shrink(),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Arborescence – $raisonSociale', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Page ${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        build: (context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: rows.map((row) {
                final node = row.node;
                final isEquipment = node.type == 'equipment';
                final isBuildingOrLevel = node.type == 'building' || node.type == 'level';
                final leftPad = 12.0 * row.depth;

                return pw.Container(
                  margin: pw.EdgeInsets.only(bottom: isEquipment ? 2 : 6),
                  padding: pw.EdgeInsets.only(
                    left: leftPad,
                    top: isBuildingOrLevel ? 6 : 3,
                    bottom: isBuildingOrLevel ? 6 : 3,
                    right: 8,
                  ),
                  decoration: isBuildingOrLevel
                      ? pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFF0F4F8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(color: PdfColor.fromInt(0xFFB6D0E2), width: 0.5),
                        )
                      : null,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        '${_typePrefix(node.type)}${node.label}',
                        style: pw.TextStyle(
                          fontSize: isBuildingOrLevel ? 11 : 10,
                          fontWeight: isBuildingOrLevel ? pw.FontWeight.bold : pw.FontWeight.normal,
                          color: isBuildingOrLevel ? PdfColors.grey800 : PdfColors.grey700,
                        ),
                      ),
                      if (node.category != null) ...[
                        pw.SizedBox(width: 6),
                        pw.Text(
                          '[${node.category}]',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                      ],
                      pw.Spacer(),
                      if (row.action != null)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: _statusColor(row.action!.status).shade(0.15),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                            border: pw.Border.all(color: _statusColor(row.action!.status), width: 0.5),
                          ),
                          child: pw.Text(
                            row.action!.status,
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: _statusColor(row.action!.status),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            // Légende statuts si intervention
            if (actions.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                  pw.SizedBox(height: 6),
                  pw.Text('Légende statuts :', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _legendBadge('V', 'Vérifié conforme', PdfColor.fromInt(0xFF4CAF50)),
                      _legendBadge('NV', 'Non vérifié', PdfColors.grey600),
                      _legendBadge('MS', 'Mise en service', PdfColor.fromInt(0xFF2196F3)),
                      _legendBadge('R', 'Réformé à remplacer', PdfColor.fromInt(0xFFFF9800)),
                      _legendBadge('HS', 'Hors service', PdfColor.fromInt(0xFFF44336)),
                      _legendBadge('P', 'Préconisation', PdfColor.fromInt(0xFF9C27B0)),
                    ],
                  ),
                ],
              ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<File> generateArborescenceReport({
    required String raisonSociale,
    required String clientId,
    required List<Node> nodes,
    List<InterventionAction> actions = const [],
  }) async {
    Uint8List? logoBytes;
    try {
      final logoData = await rootBundle.load('assets/images/veriflamme.png');
      logoBytes = logoData.buffer.asUint8List();
    } catch (_) {}

    final bytes = await buildArborescenceBytes(
      raisonSociale: raisonSociale,
      nodes: nodes,
      actions: actions,
      logoBytes: logoBytes,
    );

    final output = await getTemporaryDirectory();
    final slug = raisonSociale.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    final file = File('${output.path}/arborescence_${slug}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  static pw.Widget _legendBadge(String label, String desc, PdfColor color) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: pw.BoxDecoration(
            color: color.shade(0.15),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            border: pw.Border.all(color: color, width: 0.5),
          ),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: color)),
        ),
        pw.SizedBox(width: 4),
        pw.Text(desc, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ],
    );
  }

  static pw.Widget _cell(String text, {bool bold = false, PdfColor? color, double fontSize = 9, bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: fontSize,
          color: color,
        ),
      ),
    );
  }
}
