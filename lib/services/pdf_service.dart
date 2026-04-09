import 'dart:io';
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
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy').format(rapport.dateCreation);
    
    // UI Colors from template
    final headerBlue = PdfColor.fromInt(0xFFB6D0E2);
    final primaryColor = PdfColor.fromInt(intervention.branche == Branche.veriflamme ? 0xFFD32F2F : 0xFF2E7D32);

    final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header with logo and Title
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null)
                  pw.Container(width: 130, child: pw.Image(logo))
                else
                  pw.Text('GLOBAL PREVENTION', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                
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
                pw.SizedBox(width: 130), // Balancing
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

            // Type Selection
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                _checkbox('Vérification', true),
                pw.SizedBox(width: 25),
                _checkbox('Implantation', intervention.typeIntervention == TypeIntervention.installation),
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
            pw.SizedBox(height: 25),

            // Footer / Signatures
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SIGNATURE DU TECHNICIEN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(intervention.branche == Branche.veriflamme ? 'Veriflamme' : 'Global Prevention', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                        pw.Text('20 Avenue des Frères Montgolfier', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('69680 CHASSIEU', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('04 37 54 55 99', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('SIRET : 999 040 108 00014', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    if (signatureTechnicien != null)
                      pw.Container(
                        width: 80,
                        height: 40,
                        child: pw.Image(pw.MemoryImage(signatureTechnicien)),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        if (logo != null) pw.Container(width: 80, child: pw.Image(logo)),
                        pw.SizedBox(height: 4),
                        pw.Text(intervention.technicienNom, style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
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
    );
    
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/rapport_${rapport.numeroRapport}.pdf");
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
