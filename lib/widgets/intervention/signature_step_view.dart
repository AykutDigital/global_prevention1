import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../widgets/signature_pad.dart';
import '../../theme/app_theme.dart';

class SignatureStepView extends StatelessWidget {
  final Uint8List? signatureClient;
  final Uint8List? signatureTechnicien;
  final Function(Uint8List?) onClientSignatureChanged;
  final Function(Uint8List?) onTechnicianSignatureChanged;

  const SignatureStepView({
    super.key,
    required this.signatureClient,
    required this.signatureTechnicien,
    required this.onClientSignatureChanged,
    required this.onTechnicianSignatureChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Finalisation & Signatures', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 24),
        
        SignaturePad(
          label: 'Signature du technicien',
          initialSignature: signatureTechnicien,
          onSaved: onTechnicianSignatureChanged,
        ),
        
        const SizedBox(height: 24),
        
        SignaturePad(
          label: 'Signature du client',
          initialSignature: signatureClient,
          onSaved: onClientSignatureChanged,
        ),
        
        const SizedBox(height: 32),
        const Text(
          'En signant ce document, le client reconnaît avoir pris connaissance des travaux effectués et de l\'état de son parc matériel.',
          style: TextStyle(color: AppTheme.secondaryText, fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}
