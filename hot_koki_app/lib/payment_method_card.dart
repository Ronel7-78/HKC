import 'package:flutter/material.dart';

class PaymentMethodCard extends StatelessWidget {
  const PaymentMethodCard({
    super.key,
    required this.code,
    required this.name,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  final String code;
  final String name;
  final bool selected;
  final bool available;
  final VoidCallback? onTap;

  String get _asset => code == 'orange_money'
      ? 'assets/images/orange_money_official.png'
      : 'assets/images/mtn_mobile_money_official.jpeg';

  Color get _brandColor => code == 'orange_money'
      ? const Color(0xFFFF7900)
      : const Color(0xFFFFCB05);

  @override
  Widget build(BuildContext context) {
    final border = selected ? _brandColor : const Color(0xFFE4DED2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: available,
        label: '$name${available ? '' : ', bientôt disponible'}',
        child: InkWell(
          onTap: available ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 96,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border, width: selected ? 2.5 : 1.2),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _brandColor.withValues(alpha: .20),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  height: 68,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      _asset,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF211B15),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        available
                            ? 'Paiement mobile sécurisé'
                            : 'Bientôt disponible',
                        style: TextStyle(
                          color: available
                              ? const Color(0xFF6B5F4E)
                              : Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: selected && available
                      ? Container(
                          key: const ValueKey('selected'),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _brandColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 19,
                            color: code == 'orange_money'
                                ? Colors.white
                                : Colors.black,
                          ),
                        )
                      : Icon(
                          available
                              ? Icons.chevron_right_rounded
                              : Icons.lock_outline_rounded,
                          key: const ValueKey('idle'),
                          color: Colors.grey.shade500,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
