class LayoutConfig {
  static const Map<String, Map<String, Map<String, String>>> layouts = {
    "xbox": {
      "primary_action": {"label": "A", "color": "0xFF4CAF50", "signal_id": "BTN_SOUTH"},
      "secondary_action": {"label": "B", "color": "0xFFF44336", "signal_id": "BTN_EAST"},
      "tertiary_action": {"label": "X", "color": "0xFF2196F3", "signal_id": "BTN_WEST"},
      "quaternary_action": {"label": "Y", "color": "0xFFFFEB3B", "signal_id": "BTN_NORTH"}
    },
    "playstation": {
      "primary_action": {"label": "✕", "color": "0xFF2196F3", "signal_id": "BTN_SOUTH"},
      "secondary_action": {"label": "◯", "color": "0xFFF44336", "signal_id": "BTN_EAST"},
      "tertiary_action": {"label": "□", "color": "0xFFE91E63", "signal_id": "BTN_WEST"},
      "quaternary_action": {"label": "△", "color": "0xFF4CAF50", "signal_id": "BTN_NORTH"}
    }
  };

  // Helper method to easily grab a specific layout
  static Map<String, Map<String, String>> getLayout(bool isXbox) {
    return isXbox ? layouts["xbox"]! : layouts["playstation"]!;
  }
}