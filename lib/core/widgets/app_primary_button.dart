import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Brand primary [ElevatedButton]: 8px corners, red fill, white label.
/// Matches [AppTheme.elevatedButtonTheme] and pairs with outline inputs.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 52,
    this.width,
    this.padding,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
  });

  /// Icon + label variant (e.g. refresh, chat). Defaults to intrinsic height.
  factory AppPrimaryButton.icon({
    Key? key,
    required VoidCallback? onPressed,
    required Widget icon,
    required Widget label,
    double? height,
    double? width,
    EdgeInsetsGeometry? padding,
    Color? disabledBackgroundColor,
    Color? disabledForegroundColor,
  }) {
    return AppPrimaryButton(
      key: key,
      onPressed: onPressed,
      height: height,
      width: width,
      padding: padding,
      disabledBackgroundColor: disabledBackgroundColor,
      disabledForegroundColor: disabledForegroundColor,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          label,
        ],
      ),
    );
  }

  final VoidCallback? onPressed;
  final Widget child;

  /// Default `52`; set to `null` for intrinsic height (e.g. compact icon rows).
  final double? height;
  final double? width;

  /// Defaults to `horizontal: 24`.
  final EdgeInsetsGeometry? padding;

  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.buttonPrimaryColor,
        foregroundColor: AppTheme.buttonPrimaryTextColor,
        disabledBackgroundColor: disabledBackgroundColor,
        disabledForegroundColor: disabledForegroundColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusPrimaryButton),
        ),
        textStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
      child: child,
    );

    if (height != null || width != null) {
      return SizedBox(height: height, width: width, child: button);
    }
    return button;
  }
}
