import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'global_keys.dart';

typedef InlineToastHandler = bool Function(String message, int durationMs);

class ToastService {
  static OverlayEntry? _toastEntry;
  static Timer? _toastOverlayTimer;
  static InlineToastHandler? _inlineToastHandler;

  static void registerInlineHandler(InlineToastHandler handler) {
    _inlineToastHandler = handler;
  }

  static void unregisterInlineHandler(InlineToastHandler handler) {
    if (_inlineToastHandler == handler) {
      _inlineToastHandler = null;
    }
  }

  static void _clearOverlayToast() {
    _toastOverlayTimer?.cancel();
    _toastOverlayTimer = null;
    _toastEntry?.remove();
    _toastEntry = null;
  }

  static void show(String message, {int durationMs = 3000}) {
    _clearOverlayToast();

    final inlineHandler = _inlineToastHandler;
    if (inlineHandler != null && inlineHandler(message, durationMs)) {
      return;
    }

    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _toastEntry = OverlayEntry(
      builder: (context) =>
          _TopToastWidget(message: message, durationMs: durationMs),
    );
    overlayState.insert(_toastEntry!);

    _toastOverlayTimer = Timer(Duration(milliseconds: durationMs + 300), () {
      if (_toastEntry != null) {
        _clearOverlayToast();
      }
    });
  }
}

class _TopToastWidget extends StatefulWidget {
  final String message;
  final int durationMs;
  const _TopToastWidget({
    Key? key,
    required this.message,
    required this.durationMs,
  }) : super(key: key);

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    Future.delayed(Duration(milliseconds: widget.durationMs - 400), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 15,
      left: 25,
      right: 25,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              0,
              -60 * (1 - Curves.easeOutQuart.transform(_ctrl.value)),
            ),
            child: Opacity(opacity: _ctrl.value, child: child),
          );
        },
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF2C2C2E),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
