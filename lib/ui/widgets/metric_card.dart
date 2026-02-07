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
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmall ? 10 : 14),
      decoration: BoxDecoration(
        color: oledBlack,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: useColorBorder ? color.withAlpha(200) : Colors.white.withAlpha(40), // 調亮邊框
          width: useColorBorder ? 2.0 : 1.0,
        ),
        boxShadow: useColorBorder ? [
          BoxShadow(color: color.withAlpha(30), blurRadius: 10, spreadRadius: 0)
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(label, 
                    style: const TextStyle(
                      color: Colors.white70, // 調亮標籤文字 (原本 white38)
                      fontSize: 11, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 0.5
                    )
                  ),
                ),
              ),
              if (delta != null && deltaColor != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: deltaColor.withAlpha(150), width: 0.5),
                    ),
                    child: Text(
                      delta!,
                      style: TextStyle(
                        color: deltaColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: highlightValue ? 8 : 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value, 
              style: TextStyle(
                color: color, 
                fontSize: highlightValue ? 30 : (isSmall ? 16 : 20), 
                fontWeight: highlightValue ? FontWeight.w900 : FontWeight.bold, 
                letterSpacing: -0.5,
                height: 1.0,
              )
            ),
          ),
        ],
      ),
    );
  }
}
