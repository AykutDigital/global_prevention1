import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class MailDraftDialog extends StatefulWidget {
  final Client client;
  final Rapport rapport;
  final VoidCallback onSend;
  final TextEditingController recipientController;
  final TextEditingController subjectController;
  final TextEditingController bodyController;

  MailDraftDialog({
    super.key,
    required this.client,
    required this.rapport,
    required this.onSend,
  })  : recipientController = TextEditingController(text: client.contactEmail),
        subjectController = TextEditingController(
            text: 'Rapport de vérification ${rapport.branche.label} - ${rapport.numeroRapport}'),
        bodyController = TextEditingController(
            text: 'Bonjour ${client.contactNom},\n\n'
                'Veuillez trouver ci-joint le rapport d\'intervention n°${rapport.numeroRapport} '
                'réalisé le ${_formatDate(rapport.dateCreation)} pour le site ${client.raisonSociale}.\n\n'
                'Cordialement,\n'
                'L\'équipe Global Prevention');

  @override
  State<MailDraftDialog> createState() => _MailDraftDialogState();

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _MailDraftDialogState extends State<MailDraftDialog> {
  @override
  void dispose() {
    // Controllers belong to the parent state if passed there, 
    // but here we manage them locally in the widget instance.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.mail_outline_rounded, color: AppTheme.infoBlue),
          const SizedBox(width: 12),
          const Text('Préparer l\'envoi'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vérifiez les informations avant l\'ouverture de votre application mail.',
              style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
            ),
            const SizedBox(height: 20),
            _buildField('Destinataire', widget.recipientController, Icons.alternate_email_rounded),
            const SizedBox(height: 16),
            _buildField('Objet', widget.subjectController, Icons.label_important_outline_rounded),
            const SizedBox(height: 16),
            _buildField('Message', widget.bodyController, Icons.notes_rounded, maxLines: 6),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.infoBlueLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.veriflammeRed, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Le fichier PDF sera automatiquement joint.',
                      style: TextStyle(fontSize: 12, color: AppTheme.infoBlue, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ANNULER'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            widget.onSend();
          },
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('CONTINUER'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.infoBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.secondaryText),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18),
            hintText: label,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
