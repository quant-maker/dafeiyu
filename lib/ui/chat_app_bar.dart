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
    required this.onFootprints,
    required this.onComfy,
    required this.onNewChat,
    required this.onSettings,
  });

  static const double height = 68;

  final String title;
  final String status;
  final SceneMood mood;
  final VoidCallback onFootprints;
  final VoidCallback onComfy;
  final VoidCallback onNewChat;
  final VoidCallback onSettings;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  Color _moodColor() {
    switch (mood) {
      case SceneMood.idle:
        return AppPalette.mint;
      case SceneMood.listening:
        return AppPalette.primary;
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
            const AvatarMark(size: 34, glow: true),
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
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(AppRadii.m),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  GhostIconButton(
                    icon: Icons.photo_library_outlined,
                    tooltip: '她的足迹',
                    size: 36,
                    onPressed: onFootprints,
                  ),
                  const SizedBox(width: 2),
                  GhostIconButton(
                    icon: Icons.brush_outlined,
                    tooltip: '画画（ComfyUI）',
                    size: 36,
                    onPressed: onComfy,
                  ),
                  const SizedBox(width: 2),
                  GhostIconButton(
                    icon: Icons.auto_awesome_outlined,
                    tooltip: '新会话',
                    size: 36,
                    onPressed: onNewChat,
                  ),
                  const SizedBox(width: 2),
                  GhostIconButton(
                    icon: Icons.tune,
                    tooltip: '设置',
                    size: 36,
                    onPressed: onSettings,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.l),
          ],
        ),
      ),
    );
  }
}
