import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../common/color_extension.dart';

class ExercisesRow extends StatelessWidget {
  final Map eObj;
  final VoidCallback onPressed;
  const ExercisesRow({super.key, required this.eObj, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: _buildMedia(eObj["image"].toString(), ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eObj["title"].toString(),
                  style: TextStyle(
                    color: TColor.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  eObj["value"].toString(),
                  style: TextStyle(color: TColor.gray, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onPressed,
            icon: Image.asset(
              "assets/img/next_go.png",
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildMedia(String path) {
  final isLottie = path.toLowerCase().endsWith('.json');
  if (isLottie) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: LottieBuilder.asset(
        path,
        width: 70,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => _fallbackIcon(),
      ),
    );
  }
  return Image.asset(
    path,
    width: 60,
    height: 70,
    fit: BoxFit.cover,
    errorBuilder: (ctx, err, stack) => _fallbackIcon(),
  );
}

Widget _fallbackIcon() => Container(
  width: 70,
  height: 60,
  color: Colors.grey.shade200,
  alignment: Alignment.center,
  child: const Icon(Icons.image_not_supported, size: 28, color: Colors.grey),
);
