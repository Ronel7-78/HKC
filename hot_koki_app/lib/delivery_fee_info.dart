import 'package:flutter/material.dart';

import 'api_config.dart';

const _leaf900 = Color(0xFF1F3524);
const _leaf100 = Color(0xFFE7EEE4);
const _flame500 = Color(0xFFF06424);
const _ink = Color(0xFF211F1D);
const _inkSoft = Color(0xFF6B6864);

Future<void> showDeliveryFeePolicy(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                CircleAvatar(
                  backgroundColor: _leaf100,
                  foregroundColor: _leaf900,
                  child: Icon(Icons.local_shipping_outlined),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Politique des frais de livraison',
                    style: TextStyle(
                      color: _leaf900,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Les frais sont calculés automatiquement selon la distance entre le vendeur et l’adresse de livraison choisie.',
              style: TextStyle(color: _inkSoft, height: 1.45),
            ),
            const SizedBox(height: 16),
            const _PolicyRow(
              label: 'Moins de 3 km',
              value: '0 FCFA',
              icon: Icons.near_me_outlined,
            ),
            const SizedBox(height: 9),
            const _PolicyRow(
              label: 'À partir de 3 km',
              value: '500 FCFA',
              icon: Icons.route_outlined,
            ),
            const SizedBox(height: 14),
            const Text(
              'La distance et le montant définitifs sont enregistrés au moment de la commande.',
              style: TextStyle(color: _inkSoft, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}

class DeliveryFeeLabel extends StatelessWidget {
  const DeliveryFeeLabel({
    super.key,
    required this.fee,
    this.color = _ink,
    this.fontSize = 13,
    this.compact = false,
  });

  final dynamic fee;
  final Color color;
  final double fontSize;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
    children: [
      Flexible(
        child: Text(
          deliveryFeeText(fee),
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 3),
      InkResponse(
        onTap: () => showDeliveryFeePolicy(context),
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: color == _ink ? _flame500 : color,
          ),
        ),
      ),
    ],
  );
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE8E5E1)),
    ),
    child: Row(
      children: [
        Icon(icon, color: _flame500),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: _leaf900, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}
