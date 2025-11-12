import 'package:flutter/material.dart';

class TagChip extends StatelessWidget {
  final String text;
  final Color? color;
  final VoidCallback? onTap;
  final bool isSelected;

  const TagChip({
    super.key,
    required this.text,
    this.color,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? Theme.of(context).colorScheme.primary)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color ?? Theme.of(context).colorScheme.primary,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isSelected
                ? Colors.white
                : (color ?? Theme.of(context).colorScheme.primary),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
