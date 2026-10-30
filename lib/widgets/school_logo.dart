/// The school's logo, shown on the loading screen and the MPIN screens.
///
/// The teacher can insert their own picture from Settings → School Logo;
/// until then the bundled school seal is used.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class SchoolLogo extends StatelessWidget {
  const SchoolLogo({super.key, required this.size, this.circle = false});

  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final custom = context.select<AppState, String?>((state) => state.schoolLogoUri);

    Widget image;
    if (custom != null && custom.isNotEmpty && File(custom).existsSync()) {
      image = Image.file(
        File(custom),
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    } else {
      image = Image.asset(
        'assets/school-logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }

    if (!circle) return image;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }
}
