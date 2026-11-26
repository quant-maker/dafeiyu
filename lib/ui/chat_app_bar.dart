import 'package:flutter/material.dart';

import '../scene/scene_stage.dart' show SceneMood;
import 'avatar_mark.dart';
import 'surfaces.dart';
import 'tokens.dart';

/// Chat header: the fish avatar, name + live status line, a mood dot and the
/// cluster of secondary actions.
///
/// The widget is a [PreferredSizeWidget] so it can be dropped straight into
/// `Scaffold.appBar`. [height] is the **content** height; the build adds the
/// status-bar inset itself because `extendBodyBehindAppBar` scaffolding does
/// not do it for a custom app bar.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    required this.title,
    required this.status,
    required this.mood,
    this.avatarBase64,
    required this.onFootprints,
    required this.onComfy,
    this.comfyOnline,
    required this.onNewChat,
    required this.onSettings,
  });

  static const double height = 68;

  final String title;
  final String status;
  final SceneMood mood;
  final String? avatarBase64;
  final VoidCallback onFootprints;
  final VoidCallback onComfy;

  /// Null while unknown; true when ComfyUI answers (dot on the draw button).
  final bool? comfyOnline;

  final VoidCallback onNewChat;
  final VoidCallback onSettings;

  // 68 is the **content** height. Scaffold's `primary: true` path adds the
  // status-bar inset on top, so this widget must stay `primary`.
  @override
  Size get preferredSize => const Size.fromHeight(height);

  Color _moodColor() {
    switch (mood) {
      case SceneMood.idle:
        return AppPalette.primary;
      case SceneMood.listening:
        return AppPalette.accent;
      case SceneMood.thinking:
        return AppPalette.warm;
      case SceneMood.speaking:
        return AppPalette.primary;
      case SceneMood.away:
        return AppPalette.text3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: SizedBox(
        height: height,
        child: Row(
          children: <Widget>[
            const SizedBox(width: AppSpacing.l),
            AvatarMark(size: 34, glow: true, imageBase64: avatarBase64),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.title.copyWith(
                            color: AppPalette.text1,
                          ),
                        ),
                        Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.copyWith(
                            color: AppPalette.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  StatusDot(
                    color: _moodColor(),
                    pulse: mood == SceneMood.thinking,
                    glow: mood != SceneMood.away,
                  ),
                ],
              ),
            ),
            // Accent (red) is reserved for transient states — recording,
            // thinking, errors. Primary actions use gold.
            _ActionIcon(
              icon: Icons.auto_stories_outlined,
              tooltip: '她的足迹',
              onPressed: onFootprints,
            ),
            const SizedBox(width: 4),
            _ActionIcon(
              icon: Icons.draw_rounded,
              tooltip: '画画（ComfyUI）',
              onPressed: onComfy,
              badgeColor: comfyOnline == null
                  ? null
                  : (comfyOnline! ? AppPalette.mint : AppPalette.danger),
            ),
            const SizedBox(width: 4),
            _ActionIcon(
              icon: Icons.add_rounded,
              tooltip: '新会话',
              onPressed: onNewChat,
              accent: true,
            ),
            const SizedBox(width: 4),
            _ActionIcon(
              icon: Icons.settings_rounded,
              tooltip: '设置',
              onPressed: onSettings,
            ),
            const SizedBox(width: AppSpacing.l),
          ],
        ),
      ),
    );
  }
}

/// A 36px circular header action. [accent] marks the single gold-tinted
/// primary action; the rest stay ghost so the cluster reads quietly.
class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accent = false,
    this.badgeColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool accent;

  /// Small dot in the corner; null hides it.
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    Widget button = IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 19,
        color: accent ? AppPalette.primary : AppPalette.text2,
      ),
      style: IconButton.styleFrom(
        fixedSize: const Size(36, 36),
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
        backgroundColor: accent
            ? AppPalette.primary.withValues(alpha: .16)
            : Colors.white.withValues(alpha: .05),
        hoverColor: Colors.white.withValues(alpha: .12),
        highlightColor: Colors.white.withValues(alpha: .16),
        shape: const CircleBorder(),
      ).copyWith(
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(
            color: accent
                ? AppPalette.primary.withValues(alpha: .38)
                : Colors.white.withValues(alpha: .08),
          ),
        ),
      ),
    );
    final Color? dot = badgeColor;
    if (dot == null) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        button,
        Positioned(
          right: 1,
          bottom: 1,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.surface, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
