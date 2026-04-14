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

class PdfService {
  static Future<Uint8List> buildReportBytes({
    required Client client,
    required Intervention intervention,
    required Rapport rapport,
    required List<Equipment> equipments,
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
            // Header : Date (gauche) | Titre (centre) | Logo (droite)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Date en haut à gauche
                pw.Text('Date : $dateStr', style: const pw.TextStyle(fontSize: 10)),

                // Titre + N° centré
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('RAPPORT DE VÉRIFICATION', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.SizedBox(height: 10),
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

                // Logo en haut à droite
                if (logo != null)
                  pw.Container(width: 130, child: pw.Image(logo))
                else
                  pw.Text('GLOBAL PREVENTION', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
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
                          _infoRow('Risques particuliers :', intervention.risquesSite ?? client.risquesParticuliers ?? '-'),
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

            // Footer / Signatures côte à côte
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Signature client (gauche)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SIGNATURE DU CLIENT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.SizedBox(height: 8),
                    if (signatureClient != null)
                      pw.Container(
                        width: 150,
                        height: 60,
                        child: pw.Image(pw.MemoryImage(signatureClient!)),
                      )
                    else if (isPreview)
                      pw.Container(
                        width: 150,
                        height: 60,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300, style: pw.BorderStyle.dashed),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Center(
                          child: pw.Text('Signature client', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400)),
                        ),
                      ),
                  ],
                ),

                // Droite : infos société EN HAUT + signature technicien EN BAS
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Bloc adresse société (en haut à droite)
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            intervention.branche == Branche.veriflamme ? 'Veriflamme' : 'Global Prevention',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                          ),
                          pw.Text('20 Avenue des Frères Montgolfier', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('69680 CHASSIEU', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('04 37 54 55 99', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('SIRET : 999 040 108 00014', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    // Signature technicien (en bas à droite)
                    pw.Text('SIGNATURE DU TECHNICIEN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.SizedBox(height: 8),
                    if (signatureTechnicien != null)
                      pw.Container(
                        width: 150,
                        height: 60,
                        child: pw.Image(pw.MemoryImage(signatureTechnicien)),
                      )
                    else if (isPreview)
                      pw.Container(
                        width: 150,
                        height: 60,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300, style: pw.BorderStyle.dashed),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Center(
                          child: pw.Text('Signature\ntechnicien', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400), textAlign: pw.TextAlign.center),
                        ),
                      ),
                    pw.SizedBox(height: 4),
                    pw.Text(intervention.technicienNom, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 15),

            // Logo vertical en bas à droite (sens correct : +pi/2)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                if (logo != null)
                  pw.Transform.rotate(
                    angle: pi / 2,
                    child: pw.Container(width: 80, child: pw.Image(logo)),
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
