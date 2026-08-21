import 'package:flutter/material.dart';

const _leaf900 = Color(0xFF1F3524);
const _flame600 = Color(0xFFD94B16);
const _inkSoft = Color(0xFF6B6864);

enum LegalDocument { terms, privacy }

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});
  final LegalDocument document;

  static const version = '20 août 2026';

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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Document opérationnel à faire valider juridiquement avant la publication commerciale.',
                style: TextStyle(color: _flame600, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            ...(terms ? _terms : _privacy).map(
              (section) =>
                  _LegalSection(title: section.$1, content: section.$2),
            ),
          ],
        ),
      ),
    );
  }

  static const _terms = <(String, String)>[
    (
      '1. Objet',
      'Hot Koki met en relation des clients et des vendeurs de repas, facilite la commande, le paiement et le suivi de livraison. L’utilisation du service implique le respect des présentes conditions.',
    ),
    (
      '2. Compte utilisateur',
      'L’utilisateur fournit des informations exactes, protège son mot de passe et signale toute utilisation non autorisée. Il est responsable des actions réalisées depuis son compte.',
    ),
    (
      '3. Commandes',
      'Les prix, produits disponibles, frais de livraison et total sont présentés avant validation. Une commande payée suit les statuts affichés dans l’application. Les disponibilités peuvent évoluer.',
    ),
    (
      '4. Paiements Mobile Money',
      'Le paiement est traité par l’opérateur choisi. Une demande acceptée techniquement n’est pas un paiement réussi : seul le statut final confirmé par l’opérateur fait foi.',
    ),
    (
      '5. Annulation et remboursement',
      'L’annulation est possible uniquement aux étapes proposées dans l’application. Tout remboursement éventuel dépend de la situation de la commande et des règles de l’opérateur de paiement.',
    ),
    (
      '6. Responsabilités',
      'Hot Koki met en œuvre des moyens raisonnables pour assurer la disponibilité du service. Des interruptions réseau, opérateur ou maintenance peuvent survenir. Les vendeurs restent responsables de la préparation et de la conformité de leurs produits.',
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
    (
      '10. Contact',
      'Les coordonnées officielles d’assistance et de l’éditeur seront ajoutées avant la mise en production.',
    ),
  ];

  static const _privacy = <(String, String)>[
    (
      '1. Données collectées',
      'Hot Koki traite les informations de compte, coordonnées de contact, adresse, position autorisée, commandes, paiements, avis, notifications et données techniques nécessaires au fonctionnement et à la sécurité.',
    ),
    (
      '2. Géolocalisation',
      'La position est demandée avec votre autorisation pour trouver les vendeurs et calculer la livraison. Les coordonnées ne sont pas affichées comme texte dans les formulaires.',
    ),
    (
      '3. Paiements',
      'Les secrets opérateur restent sur le serveur. Hot Koki conserve les références, montants, statuts et numéros masqués nécessaires au suivi, à la sécurité et au rapprochement. Les jetons d’accès ne sont pas journalisés.',
    ),
    (
      '4. Finalités',
      'Les données servent à fournir le service, sécuriser les comptes et transactions, exécuter les commandes, communiquer les changements de statut, assister les utilisateurs et produire des statistiques opérationnelles.',
    ),
    (
      '5. Destinataires',
      'Les informations strictement nécessaires peuvent être communiquées au vendeur affecté, aux prestataires de paiement, d’hébergement ou de livraison et aux autorités lorsqu’une obligation légale l’impose.',
    ),
    (
      '6. Conservation',
      'Les données sont conservées pendant la durée nécessaire au service, à la sécurité, au traitement des litiges et aux obligations comptables ou réglementaires. Les durées définitives seront précisées avant publication.',
    ),
    (
      '7. Sécurité',
      'Hot Koki applique notamment le chiffrement des données sensibles, le contrôle d’accès par rôle, HTTPS, la limitation des privilèges et la surveillance des opérations importantes.',
    ),
    (
      '8. Vos choix',
      'Vous pouvez refuser la géolocalisation, corriger les informations modifiables et demander l’exercice de vos droits via le canal d’assistance qui sera publié.',
    ),
    (
      '9. Notifications',
      'Les notifications opérationnelles concernent les commandes, paiements, comptes et avis. Les réglages du téléphone peuvent limiter leur son ou leur affichage.',
    ),
    (
      '10. Contact',
      'L’identité complète du responsable du traitement et ses coordonnées seront ajoutées avant la mise en production.',
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
