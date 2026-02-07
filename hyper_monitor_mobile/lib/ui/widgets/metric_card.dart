import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final Color color;
  final Color cardBg;
  final bool isShortDelta;
  final bool isSmall;

  const MetricCard({
    super.key, 
    required this.label, 
    required this.value, 
    required this.delta, 
    required this.color, 
    required this.cardBg,
    this.isShortDelta = false,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 10 : 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: TextStyle(color: color, fontSize: isSmall ? 16 : 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              const Spacer(),
              if (delta != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (delta!.startsWith('+') ? Colors.green : Colors.red).withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    delta!,
                    style: TextStyle(
                      color: delta!.startsWith('+') ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
