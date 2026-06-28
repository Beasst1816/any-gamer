import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/layout_notifier.dart';
import '../providers/theme_notifier.dart';
import '../theme/app_theme.dart';

class LayoutEditorOverlay extends StatefulWidget {
  final VoidCallback onClose;
  const LayoutEditorOverlay({super.key, required this.onClose});

  @override
  State<LayoutEditorOverlay> createState() => _LayoutEditorOverlayState();
}

class _LayoutEditorOverlayState extends State<LayoutEditorOverlay> {
  // Add this state variable to track if the menus are showing
  bool _isMenuVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LayoutNotifier>().setEditing(true);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _close() {
    context.read<LayoutNotifier>().setEditing(false);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final layout = context.read<LayoutNotifier>();

    final accent = theme.accentColor;

    return Stack(
      children: [
        // ── Dim layer ───────────────────────────────────────────────────
        Positioned.fill(
          child: IgnorePointer(
            // Make the dim layer lighter when menus are hidden so it's easier to see
            child: Container(
              color: Colors.black.withAlpha(_isMenuVisible ? 90 : 40),
            ),
          ),
        ),

        if (_isMenuVisible) ...[
          // ── Top toolbar ─────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _TopBar(
                accent: accent,
                // FIXED: Wrapped the method call in an anonymous function
                onReset: () => layout.resetToDefault(layout.isXbox),
                onDone: _close,
                // Pass the hide function down
                onHide: () => setState(() => _isMenuVisible = false),
              ),
            ),
          ),

          // ── Bottom visibility panel ──────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _VisibilityPanel(layout: layout, accent: accent),
            ),
          ),
        ] else ...[
          // ── Floating "Show Menu" Pill ──────────────────────────────────
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _isMenuVisible = true),
                  icon: Icon(Icons.visibility, color: accent, size: 16),
                  label: Text(
                    'SHOW MENU',
                    style: AppTheme.labelStyle(
                      14,
                      color: accent,
                      weight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.kBackground.withAlpha(240),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: accent, width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Top toolbar ───────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final Color accent;
  final VoidCallback onReset;
  final VoidCallback onDone;
  final VoidCallback onHide;

  const _TopBar({
    required this.accent,
    required this.onReset,
    required this.onDone,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.kBackground.withAlpha(230),
      child: Row(
        children: [
          Text('LAYOUT EDITOR', style: AppTheme.labelStyle(18, color: accent)),
          const Spacer(),
          // Hint so the user understands what to do
          Text(
            'DRAG BUTTONS TO REPOSITION',
            style: AppTheme.labelStyle(11, color: AppTheme.kTextSecondary),
          ),
          const Spacer(),
          TextButton(
            onPressed: onHide,
            child: Text(
              'HIDE UI',
              style: AppTheme.labelStyle(13, color: AppTheme.kTextSecondary),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onReset,
            child: Text(
              'RESET',
              style: AppTheme.labelStyle(13, color: AppTheme.kTextSecondary),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onDone,
            child: Text('DONE', style: AppTheme.labelStyle(13, color: accent)),
          ),
        ],
      ),
    );
  }
}

// ── Bottom visibility panel ───────────────────────────────────────────────────

class _VisibilityPanel extends StatelessWidget {
  final LayoutNotifier layout;
  final Color accent;

  // All toggleable component keys — matches original visibility system
  static const _components = [
    'lt',
    'lb',
    'rt',
    'rb',
    'l_stick',
    'dpad',
    'buttons',
    'r_stick',
    'select',
    'start',
  ];

  const _VisibilityPanel({required this.layout, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      color: AppTheme.kBackground.withAlpha(220),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VISIBILITY',
            style: AppTheme.labelStyle(13, color: AppTheme.kTextSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _components
                .map(
                  (key) => _VisibilityChip(
                    label: key.toUpperCase(),
                    visible: layout.isVisible(key),
                    accent: accent,
                    onTap: () => layout.toggleVisibility(key),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  final String label;
  final bool visible;
  final Color accent;
  final VoidCallback onTap;

  const _VisibilityChip({
    required this.label,
    required this.visible,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: visible ? accent.withAlpha(40) : Colors.transparent,
          border: Border.all(
            color: visible ? accent : AppTheme.kHudBorder,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: AppTheme.labelStyle(
            12,
            color: visible ? accent : AppTheme.kTextSecondary,
          ),
        ),
      ),
    );
  }
}