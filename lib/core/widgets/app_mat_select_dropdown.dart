import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_outline_input.dart';

/// Outline insets for mat-select dropdowns — matches [AppCountryCodeDropdown].
const EdgeInsetsGeometry kAppMatSelectContentPadding =
    EdgeInsetsDirectional.only(start: 12, end: 4, top: 16, bottom: 16);

/// Outlined single-select (Angular `mat-select` style): floating label, 8px corners.
class AppMatSelectDropdown<T> extends StatelessWidget {
  const AppMatSelectDropdown({
    super.key,
    required this.labelText,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.menuMaxHeight = 320,
    this.contentPadding,
    this.selectedItemBuilder,
    this.decoration,
  });

  static AppMatSelectDropdown<String> strings({
    Key? key,
    required String labelText,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    Widget? hint,
    double menuMaxHeight = 320,
    EdgeInsetsGeometry? contentPadding,
    InputDecoration? decoration,
  }) {
    return AppMatSelectDropdown<String>(
      key: key,
      labelText: labelText,
      value: value,
      items: [
        for (final o in options)
          DropdownMenuItem<String>(value: o, child: Text(o)),
      ],
      onChanged: onChanged,
      hint: hint,
      menuMaxHeight: menuMaxHeight,
      contentPadding: contentPadding,
      decoration: decoration,
    );
  }

  final String labelText;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final Widget? hint;
  final double menuMaxHeight;
  final EdgeInsetsGeometry? contentPadding;
  final List<Widget> Function(BuildContext context)? selectedItemBuilder;
  final InputDecoration? decoration;

  static const TextStyle _style = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppTheme.primaryTextColor,
  );

  @override
  Widget build(BuildContext context) {
    final sanitized = _sanitizeValue(value, items);
    final padding = contentPadding ?? kAppMatSelectContentPadding;

    return DropdownButtonFormField<T>(
      key: ValueKey<String>('matselect-$labelText-${_keyPart(sanitized)}'),
      initialValue: sanitized,
      isExpanded: true,
      isDense: true,
      borderRadius:
          BorderRadius.circular(AppOutlineInputDecoration.borderRadius),
      menuMaxHeight: menuMaxHeight,
      icon: const Icon(
        Icons.arrow_drop_down_rounded,
        color: AppTheme.primaryTextColor,
      ),
      iconSize: 24,
      dropdownColor: AppTheme.surfaceColor,
      style: _style,
      hint: hint,
      decoration: decoration ??
          AppOutlineInputDecoration.outline(
            labelText: labelText,
            contentPadding: padding,
          ),
      items: items,
      selectedItemBuilder: selectedItemBuilder,
      onChanged: onChanged,
    );
  }

  static String _keyPart<T>(T? v) {
    if (v == null) return 'null';
    if (v is String) return v;
    return '${v.hashCode}';
  }

  static T? _sanitizeValue<T>(T? value, List<DropdownMenuItem<T>> items) {
    if (value == null) return null;
    final ok = items.any((e) => e.value == value);
    return ok ? value : null;
  }
}
