import 'dart:async';
import 'package:flutter/material.dart';

/// Shows a glossy snackbar-like pill using an Overlay for precise placement
void showGlossySnackbar(
  BuildContext context, {
  required String message,
  required Color color,
  IconData? icon,
  Duration duration = const Duration(seconds: 3),
}) {
  _showOverlayChip(
    context,
    message: message,
    color: color,
    icon: icon,
    duration: duration,
  );
}

/// Predefined glossy snackbar for success messages
void showSuccessSnackbar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  showGlossySnackbar(
    context,
    message: message,
    color: const Color(0xFF7FD97F), // Lighter green
    icon: Icons.check_circle,
    duration: duration,
  );
}

/// Predefined glossy snackbar for error messages
void showErrorSnackbar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  showGlossySnackbar(
    context,
    message: message,
    color: const Color(0xFFFF6B6B), // Lighter red (20% lighter)
    icon: Icons.error,
    duration: duration,
  );
}

/// Predefined glossy snackbar for warning messages
void showWarningSnackbar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  showGlossySnackbar(
    context,
    message: message,
    color: const Color(0xFFFFB347), // Lighter orange (20% lighter)
    icon: Icons.warning,
    duration: duration,
  );
}

/// Predefined glossy snackbar for info messages
void showInfoSnackbar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  showGlossySnackbar(
    context,
    message: message,
    color: const Color(0xFF66B2FF), // Lighter blue (20% lighter than 0xFF2196F3)
    icon: Icons.info,
    duration: duration,
  );
}

// ===== Overlay-based glossy chip (precise placement like ref image) =====

OverlayEntry? _activeOverlay;

void _showOverlayChip(
  BuildContext context, {
  required String message,
  required Color color,
  IconData? icon,
  Duration duration = const Duration(seconds: 3),
}) {
  // Remove any existing overlay to avoid stacking
  _activeOverlay?.remove();
  _activeOverlay = null;

  final overlay = Overlay.of(context);
  if (overlay == null) return;

  final media = MediaQuery.of(context);
  final safeInset = media.viewPadding.bottom; // gesture/nav area
  final keyboardInset = media.viewInsets.bottom; // keyboard height when visible
  const double searchBarBottom = 20.0; // from HomePage Positioned(bottom: 20)
  const double searchBarHeight = 60.0; // search bar container height
  const double pillHeight = 52.0; // this chip's height

  // Align the pill vertically to the search bar center.
  const double alignToSearchCenter = searchBarBottom + (searchBarHeight - pillHeight) / 2; // 24.0

  // If keyboard is open, anchor above keyboard with the same alignment offset.
  // Otherwise, keep it just a bit above the bottom edge or the search bar center, whichever is higher.
  final double bottom = keyboardInset > 0
      ? keyboardInset + alignToSearchCenter
      : (safeInset + 2).clamp(0, double.infinity).toDouble() < alignToSearchCenter
          ? alignToSearchCenter
          : (safeInset + 2);

  _activeOverlay = OverlayEntry(
    builder: (ctx) => IgnorePointer(
      ignoring: true, // allow touches to pass through
      child: Stack(
        children: [
          Positioned(
            left: 85,
            right: 85,
            bottom: bottom,
            child: _GlossyPill(
              message: message,
              color: color,
              icon: icon,
            ),
          ),
        ],
      ),
    ),
  );

  overlay.insert(_activeOverlay!);

  // Auto-remove after duration
  Timer(duration, () {
    _activeOverlay?.remove();
    _activeOverlay = null;
  });
}

class _GlossyPill extends StatelessWidget {
  final String message;
  final Color color;
  final IconData? icon;

  const _GlossyPill({
    required this.message,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: 52, // slimmer pill
        decoration: BoxDecoration(
          color: color.withOpacity(0.95),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
