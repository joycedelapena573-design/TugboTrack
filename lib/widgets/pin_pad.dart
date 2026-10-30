/// Numeric MPIN keypad with dot display (6-digit).
///
/// Keys stretch to the available width in four fixed rows, so the whole pad
/// always fits on screen without scrolling.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';

import '../services/mpin.dart';
import '../theme/app_theme.dart';

class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < mpinLength; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 5.5),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < value.length ? AppColors.navy : Colors.transparent,
                border: Border.all(
                  width: 2,
                  color: i <= value.length
                      ? AppColors.navy
                      : const Color(0xFFB9CEF3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const List<List<String>> _rows = [
  ['1', '2', '3'],
  ['4', '5', '6'],
  ['7', '8', '9'],
  ['', '0', 'del'],
];

class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.value, required this.onChange});

  final String value;
  final ValueChanged<String> onChange;

  void _press(String key) {
    HapticFeedback.selectionClick();
    if (key == 'del') {
      onChange(value.isEmpty ? value : value.substring(0, value.length - 1));
      return;
    }
    if (key.isEmpty) return;
    if (value.length >= mpinLength) return;
    onChange(value + key);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: key == row.last ? 0 : 10),
                      child: key.isEmpty
                          ? const SizedBox(height: 54)
                          : Material(
                              color: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                side: const BorderSide(
                                  color: AppColors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                onTap: () => _press(key),
                                child: SizedBox(
                                  height: 54,
                                  child: Center(
                                    child: key == 'del'
                                        ? const Icon(
                                            Ionicons.backspaceOutline,
                                            size: 24,
                                            color: AppColors.navy,
                                          )
                                        : Text(
                                            key,
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 22,
                                              fontWeight: AppFonts.semibold,
                                              color: AppColors.navyDark,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
