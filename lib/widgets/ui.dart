/// Shared UI building blocks styled after the approved mockups.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';

import '../theme/app_theme.dart';

class Screen extends StatelessWidget {
  const Screen({super.key, required this.child, this.padding = const EdgeInsets.only(top: 0)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.style});

  final Widget child;
  final EdgeInsetsGeometry? style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: style ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: child,
    );
  }
}

enum ButtonVariant { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.disabled = false,
    this.style,
  });

  final String label;
  final VoidCallback onTap;
  final ButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool disabled;
  final EdgeInsetsGeometry? style;

  ({Color bg, Color fg, Color? border}) get _palette {
    switch (variant) {
      case ButtonVariant.primary:
        return (bg: AppColors.navy, fg: AppColors.white, border: null);
      case ButtonVariant.secondary:
        return (bg: AppColors.ice, fg: AppColors.navy, border: null);
      case ButtonVariant.ghost:
        return (bg: Colors.transparent, fg: AppColors.navy, border: AppColors.border);
      case ButtonVariant.danger:
        return (bg: const Color(0xFFFDE4E1), fg: AppColors.red, border: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = disabled || loading;
    final palette = _palette;
    final shadows = variant == ButtonVariant.primary
        ? AppShadow.soft
        : const <BoxShadow>[];

    return Opacity(
      opacity: isDisabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              color: palette.bg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: palette.border == null
                  ? null
                  : Border.all(color: palette.border!, width: 1.5),
              boxShadow: shadows,
            ),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: palette.fg,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: palette.fg),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15.5,
                            fontWeight: AppFonts.semibold,
                            color: palette.fg,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.label,
    this.placeholder,
    this.hint,
    this.icon,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.inputFormatters,
    this.suffix,
    this.maxLength,
    this.readOnly = false,
    this.style,
  });

  final String label;
  final String? placeholder;
  final String? hint;
  final IconData? icon;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final int? maxLength;
  final bool readOnly;
  final EdgeInsetsGeometry? style;

  @override
  Widget build(BuildContext context) {
    final hintWidget = hint == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              hint!,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: AppColors.textFaint,
              ),
            ),
          );
    return Padding(
      padding: style ?? const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.5,
                fontWeight: AppFonts.semibold,
                color: AppColors.text,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.ice,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: AppColors.navy),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    keyboardType: keyboardType,
                    obscureText: obscureText,
                    inputFormatters: inputFormatters,
                    maxLength: maxLength,
                    readOnly: readOnly,
                    obscuringCharacter: '•',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15.5,
                      fontWeight: AppFonts.medium,
                      color: AppColors.text,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      hintText: placeholder,
                      hintStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15.5,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                ),
                ?suffix,
              ],
            ),
          ),
          ?hintWidget,
        ],
      ),
    );
  }
}

/// Chip selector used for grade levels, statuses and filters.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
    this.color,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.navy;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? tint : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: active ? tint : AppColors.border, width: 1.5),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.5,
              fontWeight: AppFonts.semibold,
              color: active ? AppColors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(children: [...children].fold(<Widget>[], (list, w) {
        return [...list, w, const SizedBox(width: 8)];
      })),
    );
  }
}

class SegmentedOption<T> {
  const SegmentedOption(this.value, this.label, {this.color});

  final T value;
  final String label;
  final Color? color;
}

class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChange,
  });

  final List<SegmentedOption<T>> options;
  final T value;
  final ValueChanged<T> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.ice,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (final option in options)
            Builder(builder: (context) {
              final active = option.value == value;
              final tint = option.color ?? AppColors.navy;
              return Expanded(
                child: InkWell(
                  onTap: () => onChange(option.value),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? tint : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: active ? tint : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: AppFonts.semibold,
                        color: active ? AppColors.white : AppColors.text,
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.right,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (onBack != null)
            Material(
              color: AppColors.ice,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onBack,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(Ionicons.chevronBack, color: AppColors.navy, size: 24),
                ),
              ),
            ),
          if (onBack != null) const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: AppFonts.bold,
                    color: AppColors.navyDark,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: AppColors.textSoft,
                    ),
                  ),
              ],
            ),
          ),
          if (right != null) ...[const SizedBox(width: 12), right!],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.ice,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppColors.navy),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: AppFonts.bold,
              color: AppColors.navyDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.5,
              color: AppColors.textSoft,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onAction != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: AppButton(label: actionLabel!, onTap: onAction!),
            ),
        ],
      ),
    );
  }
}

class Badge extends StatelessWidget {
  const Badge({
    super.key,
    required this.label,
    required this.color,
    required this.bg,
  });

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: AppFonts.semibold,
          color: color,
        ),
      ),
    );
  }
}

class TintText extends StatelessWidget {
  const TintText(this.child, {super.key, this.style});

  final Widget child;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: (style ?? const TextStyle()).copyWith(color: AppColors.text),
      child: child,
    );
  }
}

/// Password-style field with an eye toggle (matches the mockup's MPIN fields).
class SecureField extends StatefulWidget {
  const SecureField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.hint,
    this.icon,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final String? hint;
  final IconData? icon;

  @override
  State<SecureField> createState() => _SecureFieldState();
}

class _SecureFieldState extends State<SecureField> {
  late final TextEditingController _controller;
  bool _hidden = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant SecureField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(offset: widget.value.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Field(
      label: widget.label,
      hint: widget.hint,
      placeholder: widget.placeholder,
      icon: widget.icon,
      controller: _controller,
      onChanged: widget.onChanged,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
      obscureText: _hidden,
      suffix: IconButton(
        onPressed: () => setState(() => _hidden = !_hidden),
        icon: Icon(
          _hidden ? Ionicons.eyeOffOutline : Ionicons.eyeOutline,
          size: 22,
          color: AppColors.textFaint,
        ),
      ),
    );
  }
}
