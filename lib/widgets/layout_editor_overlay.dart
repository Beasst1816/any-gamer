import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/layout_notifier.dart';
import '../providers/theme_notifier.dart';
import '../theme/app_theme.dart';

class LayoutEditorOverlay extends StatelessWidget {
  const LayoutEditorOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final layout = context.watch<LayoutNotifier>();
    final accent = theme.accentColor;

    return Material(
      color: AppTheme.kBackground.withAlpha(230),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('LAYOUT EDITOR', style: AppTheme.labelStyle(20, color: accent)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  // Left Zone Editor
                  Expanded(
                    child: _buildReorderableList(
                      'LEFT ZONE',
                      layout.leftZone,
                      accent,
                          (oldIdx, newIdx) => context.read<LayoutNotifier>().updateLeftZone(oldIdx, newIdx),
                    ),
                  ),
                  const VerticalDivider(color: AppTheme.kHudBorder),

                  // Right Zone Editor
                  Expanded(
                    child: _buildReorderableList(
                      'RIGHT ZONE',
                      layout.rightZone,
                      accent,
                          (oldIdx, newIdx) => context.read<LayoutNotifier>().updateRightZone(oldIdx, newIdx),
                    ),
                  ),
                  const VerticalDivider(color: AppTheme.kHudBorder),

                  // Visibility Toggles
                  Expanded(
                    flex: 2,
                    child: _buildVisibilityList(layout, accent),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildReorderableList(String title, List<String> items, Color accent, Function(int, int) onReorder) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(title, style: AppTheme.labelStyle(16, color: AppTheme.kTextSecondary)),
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: items.length,
            onReorder: onReorder,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                key: ValueKey(item),
                title: Text(item.toUpperCase(), style: AppTheme.labelStyle(14)),
                trailing: Icon(Icons.drag_handle, color: accent),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVisibilityList(LayoutNotifier layout, Color accent) {
    final components = ['dpad', 'l_stick', 'buttons', 'r_stick', 'lt', 'lb', 'rt', 'rb', 'select', 'start'];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('VISIBILITY', style: AppTheme.labelStyle(16, color: AppTheme.kTextSecondary)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: components.length,
            itemBuilder: (context, index) {
              final key = components[index];
              return SwitchListTile(
                title: Text(key.toUpperCase(), style: AppTheme.labelStyle(14)),
                value: layout.isVisible(key),
                activeColor: accent,
                onChanged: (val) => layout.toggleVisibility(key),
              );
            },
          ),
        ),
      ],
    );
  }
}