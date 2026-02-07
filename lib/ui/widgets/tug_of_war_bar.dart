import 'package:flutter/material.dart';

class TugOfWarBar extends StatelessWidget {
  final String label;
  final double leftVal;
  final double rightVal;
  final Color leftColor;
  final Color rightColor;
  final String leftLabel;
  final String rightLabel;
  final Color cardBg;

  const TugOfWarBar({
    super.key,
    required this.label,
    required this.leftVal,
    required this.rightVal,
    required this.leftColor,
    required this.rightColor,
    required this.leftLabel,
    required this.rightLabel,
    required this.cardBg,
  });

  String _formatCompact(double v) {
    double absV = v.abs();
    if (absV >= 1e8) return "${(v / 1e8).toStringAsFixed(2)}億";
    if (absV >= 1e4) return "${(v / 1e4).toStringAsFixed(0)}萬";
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final total = leftVal + rightVal;
    final leftPct = total > 0 ? (leftVal / total) : 0.5;
    final rightPct = total > 0 ? (rightVal / total) : 0.5;

    String displayLeft = leftLabel.replaceAll('L', '多').replaceAll(':', '');
    String displayRight = rightLabel.replaceAll('S', '空').replaceAll(':', '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              Text("${(leftPct * 100).toStringAsFixed(1)}% vs ${(rightPct * 100).toStringAsFixed(1)}%", 
                style: const TextStyle(color: Colors.white38, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      Expanded(flex: (leftPct * 1000).round(), child: Container(color: leftColor.withAlpha(220))),
                      const SizedBox(width: 1),
                      Expanded(flex: (rightPct * 1000).round(), child: Container(color: rightColor.withAlpha(220))),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1.5,
                height: 10,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 顯示「多 $數值」
              Text("$displayLeft \$${_formatCompact(leftVal)}", 
                style: TextStyle(color: leftColor, fontSize: 9, fontWeight: FontWeight.w900)),
              // 顯示「$數值 空」
              Text("\$${_formatCompact(rightVal)} $displayRight", 
                style: TextStyle(color: rightColor, fontSize: 9, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}
