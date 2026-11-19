import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

class CommunityEmojiPicker extends StatelessWidget {
  const CommunityEmojiPicker({
    super.key,
    required this.onSelected,
    this.enabled = true,
    this.forComposer = false,
  });
  final ValueChanged<String> onSelected;
  final bool enabled;
  final bool forComposer;

  @override
  Widget build(BuildContext context) => UiDropdownMenu(
    axis: Axis.horizontal,
    width: context.sz(240),
    maxHeight: 64,
    size: UiSize.lg,
    enabled: enabled,
    alignRight: forComposer,
    items: [
      for (final reaction in const [
        ('👍', 'Like'),
        ('🚀', 'Bullish'),
        ('💡', 'Insightful'),
        ('🔥', 'Fire'),
        ('❤️', 'Love'),
      ])
        UiMenuItem(
          label: reaction.$1,
          leading: CommunityReactionGlyph(emoji: reaction.$1),
          description: reaction.$2,
          onTap: () => onSelected(reaction.$1),
        ),
    ],
    child: UiIconButton(
      icon: forComposer
          ? Icons.sentiment_satisfied_alt_outlined
          : Icons.add_reaction_outlined,
      tooltip: forComposer ? 'Insert emoji' : 'React with emoji',
      size: UiSize.sm,
      variant: UiVariant.ghost,
    ),
  );
}

/// A complete emoji glyph, independent of text-button padding and text scaling.
class CommunityReactionGlyph extends StatelessWidget {
  const CommunityReactionGlyph({super.key, required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) => Text(
    emoji,
    textAlign: TextAlign.center,
    textScaler: TextScaler.noScaling,
    style: TextStyle(fontSize: context.sz(context.ui.sizes.iconLg), height: 1),
  );
}
