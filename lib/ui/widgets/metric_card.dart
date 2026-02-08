import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final Color color; 
  final Color cardBg;
  final bool isSmall;
  final bool highlightValue;
  final bool useColorBorder; 

  const MetricCard({
    super.key, 
    required this.label, 
    required this.value, 
    required this.delta, 
    required this.color, 
    required this.cardBg,
    this.isSmall = false,
    this.highlightValue = false,
    this.useColorBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    const textGreen = Color(0xFF00FF9D); 
    const textRed = Color(0xFFFF2E2E);
    // 1:1 還原：背景色使用純黑 (OLED Black)
    const oledBlack = Color(0xFF000000);

    Color? deltaColor;
    bool isPositive = delta?.startsWith('+') ?? false;
    
    if (delta != null) {
      if (color == textRed) {
        deltaColor = isPositive ? textRed : textGreen;
      } else {
        deltaColor = isPositive ? textGreen : textRed;
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: isSmall ? 10 : 16),
      decoration: BoxDecoration(
        color: oledBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: useColorBorder ? color.withAlpha(220) : Colors.white.withAlpha(30),
          width: useColorBorder ? 1.5 : 1.0,
        ),
        boxShadow: useColorBorder ? [
          BoxShadow(color: color.withAlpha(40), blurRadius: 12, spreadRadius: 0)
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 22), 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                if (delta != null && deltaColor != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: deltaColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: deltaColor.withAlpha(100), width: 0.5),
                    ),
                    child: Text(delta!, style: TextStyle(color: deltaColor, fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                  )
                else
                  const SizedBox(height: 18),
              ],
            ),
          ),
          SizedBox(height: highlightValue ? 12 : 6),
          SizedBox(
            height: highlightValue ? 36 : 24,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(color: color, fontSize: highlightValue ? 32 : (isSmall ? 18 : 22), fontWeight: highlightValue ? FontWeight.w900 : FontWeight.bold, letterSpacing: -0.5, height: 1.0)),
            ),
          ),
        ],
      ),
    );
  }
}
