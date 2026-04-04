import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Shared [OutlineInputBorder] radius (8dp), aligned with app outline fields.
class AppOutlineInputDecoration {
  AppOutlineInputDecoration._();

  static double get borderRadius => AppTheme.radiusPrimaryButton;

  /// Material-style outlined field (floating label) for [TextField], [TextFormField],
  /// [DropdownButtonFormField], etc.
  static InputDecoration outline({
    required String labelText,
    String? hintText,
    String? counterText,
    String? errorText,
    String? helperText,
    int? errorMaxLines,
    Widget? prefixIcon,
    Widget? prefix,
    Widget? suffixIcon,
    Color? fillColor,
    EdgeInsetsGeometry? contentPadding,
    FloatingLabelBehavior floatingLabelBehavior = FloatingLabelBehavior.auto,
  }) {
    final r = BorderRadius.circular(borderRadius);
    const idleSide = BorderSide(color: AppTheme.inputBorderColor);
    const focusedSide = BorderSide(color: AppTheme.primaryColor, width: 2);
    const errorSide = BorderSide(color: AppTheme.errorColor);

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      floatingLabelBehavior: floatingLabelBehavior,
      labelStyle: const TextStyle(
        color: AppTheme.secondaryTextColor,
        fontSize: 15,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppTheme.primaryColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(
        color: AppTheme.hintTextColor,
        fontSize: 15,
      ),
      prefixIcon: prefixIcon,
      prefix: prefix,
      suffixIcon: suffixIcon,
      counterText: counterText,
      errorText: errorText,
      helperText: helperText,
      errorMaxLines: errorMaxLines,
      filled: true,
      fillColor: fillColor ?? AppTheme.inputBackgroundColor,
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: r, borderSide: idleSide),
      enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: idleSide),
      focusedBorder: OutlineInputBorder(borderRadius: r, borderSide: focusedSide),
      errorBorder: OutlineInputBorder(borderRadius: r, borderSide: errorSide),
      focusedErrorBorder:
          OutlineInputBorder(borderRadius: r, borderSide: errorSide.copyWith(width: 2)),
      disabledBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(
          color: AppTheme.inputBorderColor.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

/// Opinionated [TextField] using [AppOutlineInputDecoration.outline].
class AppOutlineTextField extends StatelessWidget {
  const AppOutlineTextField({
    super.key,
    required this.labelText,
    this.hintText,
    this.counterText,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.decoration,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.style,
    this.readOnly = false,
    this.showCursor,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.inputFormatters,
    this.enabled = true,
    this.onTap,
  });

  final String labelText;
  final String? hintText;
  final String? counterText;
  final Widget? prefixIcon;
  final Widget? prefix;
  final Widget? suffixIcon;
  final InputDecoration? decoration;

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final TextStyle? style;
  final bool readOnly;
  final bool? showCursor;
  final bool autofocus;
  final bool obscureText;
  final bool autocorrect;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      textAlign: textAlign,
      style: style ??
          const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
      readOnly: readOnly,
      showCursor: showCursor,
      autofocus: autofocus,
      obscureText: obscureText,
      autocorrect: autocorrect,
      maxLines: maxLines,
      minLines: minLines,
      expands: expands,
      maxLength: maxLength,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      enabled: enabled,
      onTap: onTap,
      decoration: decoration ??
          AppOutlineInputDecoration.outline(
            labelText: labelText,
            hintText: hintText,
            counterText: counterText,
            prefixIcon: prefixIcon,
            prefix: prefix,
            suffixIcon: suffixIcon,
          ),
    );
  }
}
