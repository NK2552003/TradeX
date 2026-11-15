/// Non-web stub for browser tab visibility detection.
bool readWebDocumentVisible() => true;

/// Non-web stub; returns a no-op unsubscribe callback.
void Function() registerWebVisibilityListener(
  void Function(bool isVisible) onChanged,
) => () {};
