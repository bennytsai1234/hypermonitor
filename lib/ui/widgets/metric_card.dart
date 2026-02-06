import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final bool isShortDelta;
  final bool isSmall;
  final Color color;
  final Color cardBg;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.isShortDelta = false,
    this.isSmall = false,
    required this.color,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    Color deltaColor = Colors.grey;
    if (delta != null) {
      bool isPositive = delta!.startsWith('+');
      deltaColor = isShortDelta
          ? (isPositive ? const Color(0xFFFF4949) : const Color(0xFF00C087))
          : (isPositive ? const Color(0xFF00C087) : const Color(0xFFFF4949));
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 16, horizontal: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(isSmall ? 40 : 100), width: isSmall ? 1.0 : 1.5),
        boxShadow: [
          BoxShadow(color: color.withAlpha(isSmall ? 10 : 30), blurRadius: isSmall ? 6 : 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.white54, fontSize: isSmall ? 11 : 13)), // Increased from 9/11
              if (delta != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: deltaColor.withAlpha(45), // Stronger background
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    delta!,
                    style: TextStyle(
                      color: deltaColor,
                      fontSize: isSmall ? 13 : 15, // Increased from 11/13
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value.replaceAll("亿", "億").replaceAll("万", "萬"),
            style: TextStyle(
              color: color,
              fontSize: isSmall ? 18 : 24, // Increased from 15/20
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ),
    );
  }
}
