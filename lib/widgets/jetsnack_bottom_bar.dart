import 'package:flutter/material.dart';
import '../theme/jetsnack_theme.dart';

class JetsnackBottomBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  const JetsnackBottomBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = JetsnackTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.iconPrimary,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Item(index: 0, label: 'FEED', icon: Icons.home, selected: currentIndex == 0, onTap: onTap),
          _Item(index: 1, label: 'SEARCH', icon: Icons.search, selected: currentIndex == 1, onTap: onTap),
          _Item(index: 2, label: 'CART', icon: Icons.shopping_cart, selected: currentIndex == 2, onTap: onTap),
          _Item(index: 3, label: 'PROFILE', icon: Icons.person, selected: currentIndex == 3, onTap: onTap),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final int index;
  final String label;
  final IconData icon;
  final bool selected;
  final void Function(int) onTap;
  const _Item({required this.index, required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = JetsnackTheme.of(context);
    final width = selected ? 140.0 : 64.0;
    final tint = selected ? colors.iconInteractive : colors.iconInteractiveInactive;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutExpo,
      width: width,
      height: 40,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onTap(index),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.iconInteractive, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: tint, size: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: selected
                    ? Padding(
                        key: const ValueKey('label'),
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(label, style: TextStyle(color: tint, fontWeight: FontWeight.w600)),
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              )
            ],
          ),
        ),
      ),
    );
  }
}