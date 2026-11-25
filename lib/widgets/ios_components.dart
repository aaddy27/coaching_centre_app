import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Apple Human Interface Guidelines (iOS Native) Color Palette & Shared Widgets
class IosTheme {
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color systemGreen = Color(0xFF34C759);
  static const Color systemOrange = Color(0xFFFF9500);
  static const Color systemRed = Color(0xFFFF3B30);
  static const Color systemIndigo = Color(0xFF5856D6);
  static const Color systemPurple = Color(0xFFAF52DE);

  static const Color groupedBg = Color(0xFFF2F2F7);
  static const Color cardBg = Colors.white;
  static const Color labelPrimary = Color(0xFF1C1C1E);
  static const Color labelSecondary = Color(0xFF3C3C43);
  static const Color labelTertiary = Color(0xFF8E8E93);
  static const Color separator = Color(0xFFE5E5EA);
  static const Color fillGray = Color(0xFFE5E5EA);
}

/// Shows a crisp iOS-style floating banner toast
void showIosToast(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = CupertinoIcons.checkmark_alt_circle_fill,
  Color iconColor = IosTheme.systemGreen,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: IosTheme.labelPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: duration,
      content: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFFE5E5EA),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// iOS Navigation Bar with back chevron + optional trailing widget
class IosNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  final bool showBack;

  const IosNavBar({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
    this.showBack = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0x26000000), width: 0.5),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              if (showBack)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(44, 44),
                  onPressed: onBack ?? () => Navigator.maybePop(context),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.chevron_left,
                        color: IosTheme.primaryBlue,
                        size: 22,
                      ),
                      SizedBox(width: 2),
                      Text(
                        'Back',
                        style: TextStyle(
                          color: IosTheme.primaryBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: IosTheme.labelPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: IosTheme.labelTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: trailing!,
                )
              else if (showBack)
                const SizedBox(width: 72)
              else
                const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS Inset Grouped Card Container
class IosGroupedCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  const IosGroupedCard({
    super.key,
    required this.children,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: IosTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IosTheme.separator, width: 0.6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// iOS Uppercase Section Header above an Inset Grouped Card
class IosSectionLabel extends StatelessWidget {
  final String text;

  const IosSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: IosTheme.labelTertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Full-width iOS Primary Action Button
class IosPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color color;
  final IconData? icon;

  const IosPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.color = IosTheme.primaryBlue,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        color: color,
        disabledColor: color.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(13),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const CupertinoActivityIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
