import 'package:flutter/material.dart';

import 'tokens.dart';

/// Tone of an [InlineNotice].
enum NoticeTone { info, success, danger }

/// Tone of a [Pill].
enum PillTone { neutral, primary, success, danger }

Color _noticeColor(NoticeTone tone) {
  switch (tone) {
    case NoticeTone.info:
      return AppPalette.primary;
    case NoticeTone.success:
      return AppPalette.mint;
    case NoticeTone.danger:
      return AppPalette.danger;
  }
}

IconData _noticeIcon(NoticeTone tone) {
  switch (tone) {
    case NoticeTone.info:
      return Icons.info_outline;
    case NoticeTone.success:
      return Icons.check_circle_outline;
    case NoticeTone.danger:
      return Icons.error_outline;
  }
}

Color _pillBackground(PillTone tone) {
  switch (tone) {
    case PillTone.neutral:
      return Colors.white.withValues(alpha: .05);
    case PillTone.primary:
      return AppPalette.primary.withValues(alpha: .16);
    case PillTone.success:
      return AppPalette.mint.withValues(alpha: .14);
    case PillTone.danger:
      return AppPalette.danger.withValues(alpha: .14);
  }
}

Color _pillBorder(PillTone tone) {
  switch (tone) {
    case PillTone.neutral:
      return AppPalette.line;
    case PillTone.primary:
      return AppPalette.primary.withValues(alpha: .30);
    case PillTone.success:
      return AppPalette.mint.withValues(alpha: .30);
    case PillTone.danger:
      return AppPalette.danger.withValues(alpha: .30);
  }
}

Color _pillForeground(PillTone tone) {
  switch (tone) {
    case PillTone.neutral:
      return AppPalette.text2;
    case PillTone.primary:
      return AppPalette.primary;
    case PillTone.success:
      return AppPalette.mint;
    case PillTone.danger:
      return AppPalette.danger;
  }
}

/// Opaque rounded card used to group related content.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppPalette.line),
      ),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppType.label.copyWith(color: AppPalette.text2),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          subtitle!,
                          style: AppType.caption.copyWith(
                            color: AppPalette.text3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (children.isNotEmpty) const SizedBox(height: AppSpacing.m),
          ...children,
        ],
      ),
    );
  }
}

/// Small uppercase-free label that introduces a group of rows.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppType.label.copyWith(color: AppPalette.text3),
    );
  }
}

/// A label + description above a full-width control.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.description,
    required this.child,
  });

  final String label;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: AppType.bodySmall.copyWith(color: AppPalette.text2),
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              description!,
              style: AppType.caption.copyWith(color: AppPalette.text3),
            ),
          ),
        const SizedBox(height: AppSpacing.s),
        child,
      ],
    );
  }
}

/// Rounded, optionally tappable chip.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.tone = PillTone.neutral,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final PillTone effective = selected ? PillTone.primary : tone;
    final Color foreground = _pillForeground(effective);
    final Widget pill = Container(
      decoration: BoxDecoration(
        color: _pillBackground(effective),
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: _pillBorder(effective)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: 6,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppType.caption.copyWith(color: foreground),
          ),
        ],
      ),
    );

    if (onTap == null) return pill;
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: pill),
      ),
    );
  }
}

/// A 9px status indicator that can optionally glow or breathe.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.color,
    this.pulse = false,
    this.glow = false,
  });

  final Color color;
  final bool pulse;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final Widget dot = Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: .45),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
    );
    if (!pulse) return dot;
    return _PulsingDot(child: dot);
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.child});

  final Widget child;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.breathe,
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1, end: .55).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

/// A 38px, low-contrast icon button with a hover/pressed overlay.
class GhostIconButton extends StatelessWidget {
  const GhostIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.size = 38,
  }) : assert(tooltip.length > 0, 'GhostIconButton.tooltip must not be empty');

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: color ?? AppPalette.text2),
      style: IconButton.styleFrom(
        fixedSize: Size(size, size),
        minimumSize: Size(size, size),
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white.withValues(alpha: .05),
        hoverColor: Colors.white.withValues(alpha: .10),
        highlightColor: Colors.white.withValues(alpha: .14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.m),
        ),
      ),
    );
  }
}

/// Primary gradient call-to-action with an inline loading state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;
    final Widget content = loading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppPalette.primaryInk,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 18, color: AppPalette.primaryInk),
                const SizedBox(width: AppSpacing.s),
              ],
              Text(
                label,
                style: AppType.subtitle.copyWith(
                  color: AppPalette.primaryInk,
                ),
              ),
            ],
          );

    final Widget button = SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.send,
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.full),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Center(widthFactor: 1, child: content),
            ),
          ),
        ),
      ),
    );

    if (enabled) return button;
    return Opacity(opacity: .6, child: button);
  }
}

/// Inline feedback bar for errors and notices.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.message,
    this.tone = NoticeTone.danger,
    this.onDismiss,
  });

  final String message;
  final NoticeTone tone;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final Color accent = _noticeColor(tone);
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppRadii.m),
        border: Border.all(color: accent.withValues(alpha: .28)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(_noticeIcon(tone), size: 16, color: accent),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: SelectableText(
              message,
              style: AppType.caption.copyWith(
                fontSize: 12.5,
                color: AppPalette.text1,
              ),
            ),
          ),
          if (onDismiss != null)
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: '关闭',
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 16),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  foregroundColor: AppPalette.text2,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(44, 44),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
