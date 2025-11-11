import 'package:flutter/material.dart';
import 'dart:ui';

// Alert type enum
enum AlertType {
  success,
  warning,
  error,
  info,
}

// Alert color constants
class AlertColors {
  static const ALERT_GREEN_LIGHT = Color(0xFF66BB6A);
  static const ALERT_GREEN_DARK = Color(0xFF43A047);
  static const ALERT_ORANGE_LIGHT = Color(0xFFFFA726);
  static const ALERT_ORANGE_DARK = Color(0xFFFFB8C00);
  static const ALERT_RED_LIGHT = Color(0xFFEF5350);
  static const ALERT_RED_DARK = Color(0xFFE53935);
  static const ALERT_NEUTRAL_LIGHT = Color(0xFF9E9E9E);
  static const ALERT_NEUTRAL_DARK = Color(0xFF757575);
}

// Alert style configuration
class AlertStyle {
  final List<Color> gradientColors;
  final Color shadowColor;
  final IconData icon;
  final String name;

  const AlertStyle({
    required this.gradientColors,
    required this.shadowColor,
    required this.icon,
    required this.name,
  });
}

// Get alert style based on type
AlertStyle getAlertStyle(AlertType type) {
  switch (type) {
    case AlertType.success:
      return AlertStyle(
        gradientColors: [
          AlertColors.ALERT_GREEN_LIGHT.withOpacity(0.85),
          AlertColors.ALERT_GREEN_DARK.withOpacity(0.95),
        ],
        shadowColor: Colors.green.shade300,
        icon: Icons.check_circle_rounded,
        name: 'success',
      );
    case AlertType.warning:
      return AlertStyle(
        gradientColors: [
          AlertColors.ALERT_ORANGE_LIGHT.withOpacity(0.85),
          AlertColors.ALERT_ORANGE_DARK.withOpacity(0.95),
        ],
        shadowColor: Colors.orange.shade300,
        icon: Icons.warning_rounded,
        name: 'warning',
      );
    case AlertType.error:
      return AlertStyle(
        gradientColors: [
          AlertColors.ALERT_RED_LIGHT.withOpacity(0.85),
          AlertColors.ALERT_RED_DARK.withOpacity(0.95),
        ],
        shadowColor: Colors.red.shade300,
        icon: Icons.error_rounded,
        name: 'error',
      );
    case AlertType.info:
      return AlertStyle(
        gradientColors: [
          AlertColors.ALERT_NEUTRAL_LIGHT.withOpacity(0.85),
          AlertColors.ALERT_NEUTRAL_DARK.withOpacity(0.95),
        ],
        shadowColor: Colors.grey.shade400,
        icon: Icons.info_rounded,
        name: 'info',
      );
  }
}

class SuccessAlertBar extends StatefulWidget {
  final String message;
  final VoidCallback? onDismiss;
  final Duration duration;
  final AlertType type;
  final VoidCallback? onActionPressed;
  final String? actionLabel;

  const SuccessAlertBar({
    Key? key,
    required this.message,
    this.onDismiss,
    this.duration = const Duration(seconds: 4),
    this.type = AlertType.success,
    this.onActionPressed,
    this.actionLabel,
  }) : super(key: key);

  @override
  State<SuccessAlertBar> createState() => _SuccessAlertBarState();
}

class _SuccessAlertBarState extends State<SuccessAlertBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Start animation
    _controller.forward();

    // Auto-dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    if (mounted && widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alertStyle = getAlertStyle(widget.type);
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(36),
          color: Colors.transparent,
          shadowColor: alertStyle.shadowColor.withOpacity(0.4),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                // Outer glow
                BoxShadow(
                  color: alertStyle.shadowColor.withOpacity(0.5),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
                // Inner shadow for depth
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: -4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: alertStyle.gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 1.8,
                    ),
                    // Glass-like inner highlight
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 6,
                        spreadRadius: -2,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with glass bubble effect
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          alertStyle.icon,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            height: 1.3,
                            decoration: TextDecoration.none, // Remove underline
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.actionLabel != null && widget.onActionPressed != null) ...[
                        const SizedBox(width: 10),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onActionPressed,
                            borderRadius: BorderRadius.circular(20),
                            splashColor: Colors.white.withOpacity(0.2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.actionLabel!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      // Close button with hover effect
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _dismiss,
                          borderRadius: BorderRadius.circular(24),
                          splashColor: Colors.white.withOpacity(0.2),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ========== UNIFIED ALERT API ==========
// Main helper function - use this everywhere
void showAlert(
  BuildContext context,
  String message,
  AlertType type, {
  Duration? duration,
  VoidCallback? onActionPressed,
  String? actionLabel,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 24, // Same height as search/scroll buttons
      left: 80, // Leave space for search FAB (60px + 20px margin)
      right: 80, // Leave space for scroll-to-top button (60px + 20px margin)
      child: SuccessAlertBar(
        message: message,
        type: type,
        duration: duration ?? const Duration(seconds: 4),
        onActionPressed: onActionPressed,
        actionLabel: actionLabel,
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    ),
  );

  overlay.insert(overlayEntry);
}

// Convenience methods for specific alert types
void showSuccessAlert(BuildContext context, String message, {Duration? duration}) {
  showAlert(context, message, AlertType.success, duration: duration);
}

void showWarningAlert(BuildContext context, String message, {Duration? duration, VoidCallback? onActionPressed, String? actionLabel}) {
  showAlert(context, message, AlertType.warning, duration: duration, onActionPressed: onActionPressed, actionLabel: actionLabel);
}

void showErrorAlert(BuildContext context, String message, {Duration? duration}) {
  showAlert(context, message, AlertType.error, duration: duration);
}

void showInfoAlert(BuildContext context, String message, {Duration? duration}) {
  showAlert(context, message, AlertType.info, duration: duration);
}
