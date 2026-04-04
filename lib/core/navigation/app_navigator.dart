import 'package:flutter/material.dart';

/// Root [Navigator] key so the splash screen can leave the route even if
/// [BuildContext]–based [Navigator.of] lookup misbehaves on some devices.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
