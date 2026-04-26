import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../theme/app_theme.dart';

class SignaturePad extends StatefulWidget {
  final String label;
  final Function(Uint8List?) onSaved;
  final Uint8List? initialSignature;

  const SignaturePad({
    super.key,
    required this.label,
    required this.onSaved,
    this.initialSignature,
  });

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  late SignatureController _controller;
  bool _hasInitialSignature = false;
  bool _captured = false;

  @override
  void initState() {
    super.initState();
    _hasInitialSignature = widget.initialSignature != null;
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (_captured) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 16),
              const SizedBox(width: 4),
              const Text('Capturée', style: TextStyle(color: AppTheme.successGreen, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _captured ? AppTheme.successGreen : AppTheme.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              if (_hasInitialSignature)
                Container(
                  height: 150,
                  width: double.infinity,
                  color: AppTheme.background,
                  child: Image.memory(widget.initialSignature!, fit: BoxFit.contain),
                )
              else
                Signature(
                  controller: _controller,
                  height: 150,
                  backgroundColor: AppTheme.background,
                ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppTheme.divider)),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.veriflammeRed),
                      onPressed: () {
                        _controller.clear();
                        setState(() { _hasInitialSignature = false; _captured = false; });
                        widget.onSaved(null);
                      },
                      tooltip: 'Effacer',
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: AppTheme.successGreen),
                      onPressed: () async {
                        if (_controller.isNotEmpty) {
                          final signature = await _controller.toPngBytes();
                          widget.onSaved(signature);
                          if (mounted) setState(() => _captured = true);
                        }
                      },
                      tooltip: 'Valider',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
