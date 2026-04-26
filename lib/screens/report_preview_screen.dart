import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../services/pdf_service.dart';
import '../services/supabase_service.dart';
import '../widgets/mail_draft_dialog.dart';

class RapportPreviewScreen extends StatefulWidget {
  final Client client;
  final Intervention intervention;
  final Rapport rapport;
  final Uint8List? signatureClient;
  final Uint8List? signatureTechnicien;
  final List<Equipment>? equipments;
  final bool isPreview;

  const RapportPreviewScreen({
    super.key,
    required this.client,
    required this.intervention,
    required this.rapport,
    this.signatureClient,
    this.signatureTechnicien,
    this.equipments,
    this.isPreview = false,
  });

  @override
  State<RapportPreviewScreen> createState() => _RapportPreviewScreenState();
}

class _RapportPreviewScreenState extends State<RapportPreviewScreen> {
  List<Equipment>? _equipments;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _equipments = widget.equipments;
    if (_equipments == null) {
      _fetchEquipments();
    }
  }

  Future<void> _fetchEquipments() async {
    setState(() => _isLoading = true);
    try {
      final list = await SupabaseService.instance.equipmentStream(widget.client.clientId).first;
      if (mounted) {
        setState(() {
          _equipments = list.where((e) => e.branche == widget.intervention.branche).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<File>?> _downloadInterventionPhotos() async {
    try {
      final photos = await SupabaseService.instance
          .getInterventionPhotosStream(widget.intervention.interventionId)
          .first;
      if (photos.isEmpty) return null;

      final tmpDir = await getTemporaryDirectory();
      final files = <File>[];
      for (final photo in photos) {
        try {
          final response = await http.get(Uri.parse(photo.url));
          if (response.statusCode == 200) {
            final file = File('${tmpDir.path}/photo_${photo.id}.jpg');
            await file.writeAsBytes(response.bodyBytes);
            files.add(file);
          }
        } catch (e) {
          debugPrint('Erreur téléchargement photo ${photo.id}: $e');
        }
      }
      return files.isEmpty ? null : files;
    } catch (e) {
      debugPrint('Erreur récupération photos: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPreview
          ? 'Prévisualisation du rapport'
          : 'Rapport ${widget.rapport.numeroRapport}'),
        actions: [
          if (!widget.isPreview && (widget.rapport.pdfUrl != null || (widget.signatureClient != null && widget.signatureTechnicien != null)))
            IconButton(
              icon: const Icon(Icons.send_rounded),
              tooltip: 'Envoyer par e-mail',
              onPressed: () => _handleSendEmailDraft(context),
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.isPreview)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3E0),
                border: Border(bottom: BorderSide(color: Color(0xFFF57C00), width: 2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.visibility_rounded, color: Color(0xFFF57C00), size: 20),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'PRÉVISUALISATION — Ce document n\'a aucune valeur sans signature',
                      style: TextStyle(color: Color(0xFFF57C00), fontWeight: FontWeight.w600, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: PdfPreview(
              build: (format) async {
                if (widget.isPreview) {
                  Uint8List? logoBytes;
                  try {
                    final logoData = await rootBundle.load(
                      widget.intervention.branche == Branche.veriflamme
                          ? 'assets/images/veriflamme.png'
                          : 'assets/images/sauvdefib.png',
                    );
                    logoBytes = logoData.buffer.asUint8List();
                  } catch (e) {
                    debugPrint('Erreur logo: $e');
                  }
                  return PdfService.buildReportBytes(
                    client: widget.client,
                    intervention: widget.intervention,
                    rapport: widget.rapport,
                    equipments: _equipments ?? [],
                    logoBytes: logoBytes,
                    isPreview: true,
                  );
                }

                if (widget.rapport.pdfUrl != null && widget.rapport.pdfUrl!.isNotEmpty) {
                  try {
                    final response = await http.get(Uri.parse(widget.rapport.pdfUrl!));
                    if (response.statusCode == 200) {
                      return response.bodyBytes;
                    }
                  } catch (e) {
                    debugPrint('Erreur téléchargement PDF cloud: $e');
                  }
                }

                Uint8List? logoBytes;
                try {
                  final logoData = await rootBundle.load(
                    widget.intervention.branche == Branche.veriflamme
                        ? 'assets/images/veriflamme.png'
                        : 'assets/images/sauvdefib.png',
                  );
                  logoBytes = logoData.buffer.asUint8List();
                } catch (e) {
                  debugPrint('Erreur logo: $e');
                }

                Uint8List? sigClient = widget.signatureClient;
                Uint8List? sigTech = widget.signatureTechnicien;
                if ((sigClient == null || sigTech == null) && widget.rapport.signatureUrl != null) {
                  try {
                    final sigData = jsonDecode(widget.rapport.signatureUrl!) as Map<String, dynamic>;
                    sigClient ??= base64Decode(sigData['client'] as String);
                    sigTech ??= base64Decode(sigData['tech'] as String);
                  } catch (e) {
                    debugPrint('Impossible de décoder les signatures stockées: $e');
                  }
                }

                final photoFiles = await _downloadInterventionPhotos();

                return PdfService.buildReportBytes(
                  client: widget.client,
                  intervention: widget.intervention,
                  rapport: widget.rapport,
                  equipments: _equipments ?? [],
                  logoBytes: logoBytes,
                  signatureClient: sigClient,
                  signatureTechnicien: sigTech,
                  interventionPhotos: photoFiles,
                );
              },
              canDebug: false,
              canChangePageFormat: false,
              actions: widget.isPreview ? [] : [
                PdfPreviewAction(
                  icon: const Icon(Icons.share_rounded),
                  onPressed: (context, build, format) async {
                    final bytes = await build(format);
                    final output = await getTemporaryDirectory();
                    final file = File("${output.path}/temp_report_${widget.rapport.numeroRapport}.pdf");
                    await file.writeAsBytes(bytes);
                    await PdfService.shareFile(file, 'Rapport d\'intervention ${widget.rapport.numeroRapport}');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSendEmailDraft(BuildContext context) async {
    final draftDialog = MailDraftDialog(
      client: widget.client,
      rapport: widget.rapport,
      onSend: () async {
        Uint8List pdfBytes;
        if (widget.rapport.pdfUrl != null && widget.rapport.pdfUrl!.isNotEmpty) {
          final response = await http.get(Uri.parse(widget.rapport.pdfUrl!));
          pdfBytes = response.bodyBytes;
        } else {
          Uint8List? logoBytes;
          try {
            final logoData = await rootBundle.load(
              widget.intervention.branche == Branche.veriflamme
                  ? 'assets/images/veriflamme.png'
                  : 'assets/images/sauvdefib.png',
            );
            logoBytes = logoData.buffer.asUint8List();
          } catch (e) {
            debugPrint('Erreur logo: $e');
          }

          final photoFiles = await _downloadInterventionPhotos();

          pdfBytes = await PdfService.buildReportBytes(
            client: widget.client,
            intervention: widget.intervention,
            rapport: widget.rapport,
            equipments: _equipments ?? [],
            logoBytes: logoBytes,
            signatureClient: widget.signatureClient,
            signatureTechnicien: widget.signatureTechnicien,
            interventionPhotos: photoFiles,
          );
        }

        final output = await getTemporaryDirectory();
        final file = File("${output.path}/rapport_${widget.rapport.numeroRapport}.pdf");
        await file.writeAsBytes(pdfBytes);

        await PdfService.shareFile(
          file,
          'Rapport de vérification ${widget.rapport.branche.label} - ${widget.rapport.numeroRapport}',
          text: 'Veuillez trouver ci-joint votre rapport d\'intervention.',
        );
      },
    );

    showDialog(
      context: context,
      builder: (context) => draftDialog,
    );
  }
}
