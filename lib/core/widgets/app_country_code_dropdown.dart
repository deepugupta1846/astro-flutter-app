import 'package:flutter/material.dart';

import '../constants/login_country_options.dart';
import 'app_mat_select_dropdown.dart';

/// Country / dial-code field — same control as [AppMatSelectDropdown] (padding,
/// icon, dense layout). Pairs with [AppOutlineTextField] for the national number.
class AppCountryCodeDropdown extends StatelessWidget {
  AppCountryCodeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText = 'Country',
    this.width = 100,
    this.menuMaxHeight = 320,
    List<LoginCountryOption>? options,
    this.decoration,
    this.contentPadding,
  }) : options = options ?? kLoginCountryOptions;

  final LoginCountryOption value;
  final ValueChanged<LoginCountryOption> onChanged;
  final String labelText;
  final double? width;
  final double menuMaxHeight;
  final List<LoginCountryOption> options;

  final InputDecoration? decoration;

  /// Defaults to [kAppMatSelectContentPadding] when null.
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final o in options)
        DropdownMenuItem<LoginCountryOption>(
          value: o,
          child: Text(
            o.dialCode,
            style: const TextStyle(fontSize: 15),
          ),
        ),
    ];

    final dropdown = AppMatSelectDropdown<LoginCountryOption>(
      labelText: labelText,
      value: value,
      items: items,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      menuMaxHeight: menuMaxHeight,
      contentPadding: contentPadding,
      decoration: decoration,
      selectedItemBuilder: (ctx) {
        return options
            .map(
              (o) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      o.dialCode,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
            )
            .toList();
      },
    );

    if (width != null) {
      return SizedBox(width: width, child: dropdown);
    }
    return dropdown;
  }
}
