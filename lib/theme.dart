import 'package:flutter/material.dart';

class McColors {
  static const bg = Color(0xFF08060F);
  static const panel = Color(0xFF16122A);
  static const panel2 = Color(0xFF221C3A);
  static const text = Color(0xFFF5F1FC);
  static const muted = Color(0xFF9AA3C2);
  static const accent = Color(0xFFF7ED16);
  static const cyan = Color(0xFF27D7FF);
  static const violet = Color(0xFF9B6BFF);
  static const danger = Color(0xFFFF6B7A);
  static const line = Color(0xFF2A2444);
  static const ok = Color(0xFF27D7FF);
  static const ink = Color(0xFFF5F1FC);
  static const onAccent = Color(0xFF16140A);
  static const orange = Color(0xFFFF7A45);
}

class McTint {
  static const display = Color(0xFFF7ED16);
  static const identity = Color(0xFF27D7FF);
  static const inbox = Color(0xFF9B6BFF);
  static const device = Color(0xFFFF7A45);
  static const advanced = Color(0xFF9AA3C2);
}

ThemeData buildMoniCardTheme() {
  const scheme = ColorScheme.dark(
    surface: McColors.panel,
    primary: McColors.accent,
    onPrimary: McColors.ink,
    onSurface: McColors.text,
    error: McColors.danger,
    secondary: McColors.panel2,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: McColors.bg,
    fontFamily: 'Roboto',
    splashFactory: InkRipple.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: McColors.bg,
      foregroundColor: McColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dividerColor: McColors.line,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: McColors.panel2,
      contentTextStyle: const TextStyle(
        color: McColors.text,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: McColors.accent,
        foregroundColor: McColors.onAccent,
        elevation: 0,
        minimumSize: const Size(44, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: McColors.text,
        side: BorderSide.none,
        backgroundColor: McColors.panel,
        minimumSize: const Size(44, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: McColors.accent),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: McColors.accent,
      thumbColor: McColors.ink,
      inactiveTrackColor: McColors.panel2,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => McColors.ink),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? McColors.accent
            : McColors.panel2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: McColors.panel,
      hintStyle: const TextStyle(color: McColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: McColors.accent, width: 1.4),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: McColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}

class OneUiTitle extends StatelessWidget {
  const OneUiTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.15,
              color: McColors.text,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(
                color: McColors.muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OneCircleButton extends StatelessWidget {
  const OneCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.selected = false,
  });
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: selected ? McColors.accent : McColors.panel,
        foregroundColor: selected ? McColors.onAccent : McColors.text,
        minimumSize: const Size(40, 40),
        maximumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class OneIconBadge extends StatelessWidget {
  const OneIconBadge({super.key, required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class OneGroup extends StatelessWidget {
  const OneGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final visible = children.whereType<Widget>().toList();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: McColors.panel,
        borderRadius: BorderRadius.circular(26),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 0.5,
                indent: 66,
                endIndent: 16,
                color: McColors.line,
              ),
            visible[i],
          ],
        ],
      ),
    );
  }
}

class OneRow extends StatelessWidget {
  const OneRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              OneIconBadge(icon: icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: McColors.text,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: McColors.muted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: McColors.muted,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
