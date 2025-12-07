import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class InactivityWrapper extends StatelessWidget {
  final Widget child;

  const InactivityWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent, // Capture all touches
      onPointerDown: (_) => AuthService.instance.userInteracted(),
      onPointerMove: (_) => AuthService.instance.userInteracted(),
      onPointerHover: (_) => AuthService.instance.userInteracted(),
      child: child,
    );
  }
}
