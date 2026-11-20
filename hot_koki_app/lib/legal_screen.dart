import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _leaf900 = Color(0xFF1F3524);
const _inkSoft = Color(0xFF6B6864);

enum LegalDocument { terms, privacy }

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});
  final LegalDocument document;

  static const version = '20 novembre 2026';

  @override
  Widget build(BuildContext context) {
    final terms = document == LegalDocument.terms;
    return Scaffold(
      appBar: AppBar(
        title: Text(terms ? 'Conditions d’utilisation' : 'Confidentialité'),
      ),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Text(
              terms
                  ? 'Conditions d’utilisation de Hot Koki'
                  : 'Politique de confidentialité de Hot Koki',
              style: const TextStyle(
                color: _leaf900,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Version du $version',
              style: TextStyle(color: _inkSoft),
            ),
            const SizedBox(height: 18),
            ...(terms ? _terms : _privacy).map(
              (section) =>
                  _LegalSection(title: section.$1, content: section.$2),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(
                  terms
                      ? 'https://api.hotkokichaud.digital/conditions-utilisation'
                      : 'https://api.hotkokichaud.digital/confidentialite',
                ),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Voir la version web officielle'),
            ),
          ],
        ),
      ),
    );
  }

  static const _terms = <(String, String)>[
    (
      '1. Objet',
      'Hot Koki permet de découvrir des plats, passer des commandes auprès de vendeurs partenaires, suivre leur traitement et, lorsque disponible, initier un paiement Mobile Money.',
    ),
    (
      '2. Compte utilisateur',
      'L’utilisateur fournit des informations exactes, protège son mot de passe et signale toute utilisation non autorisée. Il est responsable des actions réalisées depuis son compte.',
    ),
    (
      '3. Commandes',
      'Les prix, produits disponibles, frais de livraison, frais de paiement en ligne et total sont présentés avant validation. Les vendeurs restent responsables de la préparation, de la disponibilité et de la conformité de leurs produits.',
    ),
    (
      '4. Paiements Mobile Money',
      'Le paiement est traité par le prestataire sélectionné. Une demande technique n’est pas un paiement réussi : seul le statut final confirmé par le prestataire fait foi.',
    ),
    (
      '5. Annulation et remboursement',
      'Une commande dont le paiement est confirmé ne peut plus être annulée ou modifiée depuis l’application. En cas de difficulté, contactez l’assistance avec la référence de commande.',
    ),
    (
      '6. Responsabilités',
      'Hot Koki met en œuvre des moyens raisonnables pour assurer la disponibilité du service. Des interruptions réseau, opérateur ou maintenance peuvent survenir.',
    ),
    (
      '7. Comportements interdits',
      'Il est interdit de frauder, contourner les contrôles d’accès, perturber le service, usurper une identité ou utiliser les données d’un autre utilisateur.',
    ),
    (
      '8. Suspension',
      'Un compte peut être suspendu en cas de fraude, d’abus, de risque de sécurité ou de violation des présentes conditions.',
    ),
    (
      '9. Évolution des conditions',
      'Une nouvelle acceptation pourra être demandée lorsque ces conditions changent de manière importante.',
    ),
    ('10. Contact', 'Pour toute assistance : contact.hotkoki@gmail.com.'),
  ];

  static const _privacy = <(String, String)>[
    (
      '1. Données collectées',
      'Hot Koki traite les informations de compte, coordonnées de contact, adresse, position autorisée, commandes, paiements, avis, notifications et données techniques nécessaires au fonctionnement et à la sécurité.',
    ),
    (
      '2. Géolocalisation',
      'La position est facultative et demandée avec votre autorisation pour trouver les vendeurs, estimer la distance et exécuter la livraison. Vous pouvez retirer cette autorisation dans les réglages du téléphone.',
    ),
    (
      '3. Paiements',
      'Les codes secrets Mobile Money ne sont jamais collectés par Hot Koki. Nous conservons uniquement les références, montants, statuts et numéros masqués nécessaires au suivi, à la sécurité et au rapprochement.',
    ),
    (
      '4. Finalités',
      'Les données servent à fournir le service, sécuriser les comptes et transactions, exécuter les commandes, communiquer les changements de statut, assister les utilisateurs et produire des statistiques opérationnelles.',
    ),
    (
      '5. Destinataires',
      'Les informations strictement nécessaires peuvent être communiquées au vendeur affecté, aux prestataires de paiement, d’hébergement, d’e-mail, de notification ou de livraison et aux autorités lorsqu’une obligation légale l’impose.',
    ),
    (
      '6. Conservation',
      'Les données sont conservées pendant la durée nécessaire au service, à la sécurité, au traitement des litiges et aux obligations comptables ou réglementaires.',
    ),
    (
      '7. Sécurité',
      'Hot Koki applique notamment HTTPS, le contrôle d’accès par rôle, des mots de passe hachés, la limitation des privilèges et la surveillance des opérations importantes.',
    ),
    (
      '8. Vos choix',
      'Vous pouvez refuser la géolocalisation, corriger les informations modifiables, supprimer votre compte client depuis l’application et demander l’exercice de vos droits via le support.',
    ),
    (
      '9. Notifications',
      'Les notifications opérationnelles concernent les commandes, paiements, comptes et avis. Les réglages du téléphone peuvent limiter leur son ou leur affichage.',
    ),
    (
      '10. Contact',
      'Pour toute question relative à vos données : contact.hotkoki@gmail.com.',
    ),
  ];
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.title, required this.content});
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _leaf900,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(content, style: const TextStyle(color: _inkSoft, height: 1.5)),
      ],
    ),
  );
}
