import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DifficultyStars extends StatelessWidget {
  final String difficulty;
  final double size;
  final bool showLabel;

  const DifficultyStars({
    super.key,
    required this.difficulty,
    this.size = 14,
    this.showLabel = true,
  });

  int get _starCount {
    switch (difficulty.toLowerCase()) {
      case 'dễ':
      case 'easy':
        return 1;
      case 'trung bình':
      case 'medium':
        return 2;
      case 'khó':
      case 'hard':
        return 3;
      default:
        return 1;
    }
  }

  Color get _color {
    switch (_starCount) {
      case 1:
        return AppColors.easy;
      case 2:
        return AppColors.medium;
      case 3:
        return AppColors.hard;
      default:
        return AppColors.easy;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(3, (index) {
          final isFilled = index < _starCount;
          return Icon(
            isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: isFilled ? _color : Colors.grey.shade400,
          );
        }),
        if (showLabel) ...[
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              difficulty,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: size - 2,
                fontWeight: FontWeight.w600,
                color: _color,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

