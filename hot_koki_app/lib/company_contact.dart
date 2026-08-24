import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Remplace uniquement cette valeur par l'adresse officielle de Hot Koki.
const companySupportEmail = 'ronellando447@gmail.com';

class CompanySupportCard extends StatelessWidget {
  const CompanySupportCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    return Card(
      child: ListTile(
        onTap: () => _openEmail(context),
        leading: const CircleAvatar(child: Icon(Icons.support_agent_rounded)),
        title: Text(isEnglish ? 'Support & contact' : 'Support & contact'),
        subtitle: Text(
          isEnglish
              ? 'A question or an issue? Write to us.'
              : 'Une question ou un souci ? Écrivez-nous.',
        ),
        trailing: const Icon(Icons.open_in_new_rounded, size: 19),
      ),
    );
  }

  Future<void> _openEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: companySupportEmail,
      queryParameters: {'subject': 'Support Hot Koki'},
    );
    if (!await launchUrl(uri) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d’ouvrir l’application email."),
        ),
      );
    }
  }
}

class CompanyCopyrightFooter extends StatelessWidget {
  const CompanyCopyrightFooter({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 4),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '© ${DateTime.now().year} Hot Koki · ',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => launchUrl(
            Uri(
              scheme: 'mailto',
              path: companySupportEmail,
              queryParameters: {'subject': 'Contact Mr_root — Hot Koki'},
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Text(
              'by Mr_root',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
