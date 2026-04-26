import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../services/pdf_service.dart';
import '../services/supabase_service.dart';

class ArborescencePreviewScreen extends StatefulWidget {
  final String clientId;
  final String raisonSociale;
  final List<Node> nodes;
  final List<InterventionAction> actions;

  const ArborescencePreviewScreen({
    super.key,
    required this.clientId,
    required this.raisonSociale,
    required this.nodes,
    required this.actions,
  });

  @override
  State<ArborescencePreviewScreen> createState() => _ArborescencePreviewScreenState();
}

class _ArborescencePreviewScreenState extends State<ArborescencePreviewScreen> {
  bool _isUploading = false;
  String? _uploadedUrl;

  Future<Uint8List> _buildBytes(PdfPageFormat _) async {
    Uint8List? logoBytes;
    try {
      final data = await rootBundle.load('assets/images/veriflamme.png');
      logoBytes = data.buffer.asUint8List();
    } catch (_) {}

    return PdfService.buildArborescenceBytes(
      raisonSociale: widget.raisonSociale,
      nodes: widget.nodes,
      actions: widget.actions,
      logoBytes: logoBytes,
    );
  }

  Future<void> _uploadToSupabase() async {
    setState(() => _isUploading = true);
    try {
      final bytes = await _buildBytes(PdfPageFormat.a4);
      final tmp = await getTemporaryDirectory();
      final slug = widget.raisonSociale.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final fileName = 'arborescence_${slug}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${tmp.path}/$fileName');
      await file.writeAsBytes(bytes);

      final url = await SupabaseService.instance.uploadFile(
        'rapports',
        'arborescences/${widget.clientId}/$fileName',
        file,
      );

      if (mounted) {
        setState(() { _uploadedUrl = url; _isUploading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rapport enregistré sur Supabase'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _share(BuildContext ctx, LayoutCallback build, PdfPageFormat format) async {
    final bytes = await build(format);
    final tmp = await getTemporaryDirectory();
    final slug = widget.raisonSociale.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    final file = File('${tmp.path}/arborescence_$slug.pdf');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Arborescence – ${widget.raisonSociale}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Arborescence – ${widget.raisonSociale}'),
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: Icon(
                _uploadedUrl != null ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
                color: _uploadedUrl != null ? Colors.green : null,
              ),
              tooltip: _uploadedUrl != null ? 'Déjà enregistré sur Supabase' : 'Enregistrer sur Supabase',
              onPressed: _uploadToSupabase,
            ),
        ],
      ),
      body: PdfPreview(
        build: _buildBytes,
        canDebug: false,
        canChangePageFormat: false,
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.share_rounded),
            onPressed: _share,
          ),
        ],
      ),
    );
  }
}
