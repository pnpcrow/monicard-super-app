import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'brand.dart';
import 'controller.dart';
import 'crop_editor.dart';
import 'l10n.dart';
import 'media.dart';
import 'motion.dart';
import 'motion_editor.dart';
import 'motion_video.dart';
import 'protocol.dart' hide FileType;
import 'tags.dart';
import 'theme.dart';

class MoniCardApp extends StatelessWidget {
  const MoniCardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, c, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final msg = c.toast;
          if (msg != null) {
            c.toast = null;
            final messenger = ScaffoldMessenger.maybeOf(context);
            messenger?.hideCurrentSnackBar();
            messenger?.showSnackBar(SnackBar(content: Text(msg)));
          }
        });
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (c.onSystemBack()) {
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
          backgroundColor: McColors.bg,
          appBar: AppBar(
            backgroundColor: McColors.bg,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 56,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _LeadingSwitch(controller: c),
              ),
            ),
            title: const SizedBox.shrink(),
            actions: [
              _ConnectionChip(controller: c),
              const SizedBox(width: 6),
              OneCircleButton(
                icon: Icons.settings_outlined,
                tooltip: c.i18n.t('openSettings'),
                selected: c.inSettingsBranch,
                onPressed: () =>
                    c.inSettingsBranch ? c.back() : c.go('settings'),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _RouteSwitcher(controller: c),
            ),
          ),
        ),
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.online});
  final bool online;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? McColors.ok : const Color(0xFF636366),
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final d = controller.device;
    final online = controller.ble.connected;
    final connecting = controller.connecting;
    final label = connecting
        ? controller.i18n.t('reconnecting')
        : d == null
        ? controller.i18n.t('notConnected')
        : (online ? d.name : controller.i18n.t('savedOffline'));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: McColors.panel,
        shape: const StadiumBorder(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              customBorder: const StadiumBorder(),
              onTap: connecting
                  ? null
                  : () async {
                      if (!online && controller.hasSavedDevice) {
                        if (kIsWeb) {
                          await controller.connect(scan: true);
                          return;
                        }
                        final ok = await controller.connect(scan: false);
                        if (!ok &&
                            context.mounted &&
                            controller.hasSavedDevice &&
                            !controller.lastConnectCancelled) {
                          await showReconnectFailedDialog(context, controller);
                        }
                        return;
                      }
                      showConnectSheet(context, controller);
                    },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    connecting
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.6),
                          )
                        : _Dot(online: online),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 112),
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: McColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => showConnectSheet(context, controller),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(2, 8, 8, 8),
                child: Icon(Icons.expand_more, size: 18, color: McColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showReconnectFailedDialog(BuildContext host, AppController c) {
  final s = c.i18n;
  return showDialog<void>(
    context: host,
    builder: (context) {
      return AlertDialog(
        backgroundColor: McColors.panel,
        title: Text(s.t('reconnectFailedTitle')),
        content: Text(
          s.t('reconnectFailedBody', {'name': c.device?.name ?? 'MoniCard'}),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              showConnectSheet(host, c);
            },
            child: Text(s.t('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              c.forgetAndScan();
            },
            child: Text(s.t('forgetAndScan')),
          ),
        ],
      );
    },
  );
}

Future<void> showConnectSheet(BuildContext context, AppController c) {
  final s = c.i18n;
  final d = c.device;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: McColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: McColors.panel2,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: Text(
                  s.t('connectionMenu'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              OneGroup(
                children: [
                  if (d != null)
                    OneRow(
                      icon: Icons.badge_outlined,
                      color: McTint.device,
                      title: d.name,
                      subtitle: [
                        c.connecting
                            ? s.t('reconnecting')
                            : c.ble.connected
                            ? s.t('connected')
                            : s.t('savedOffline'),
                        if (d.battery != null)
                          '${s.t('battery')} ${d.battery}%',
                        d.firmwareVersion,
                      ].whereType<String>().join(' · '),
                      trailing: _Dot(online: c.ble.connected),
                    ),
                  OneRow(
                    icon: Icons.bluetooth_searching,
                    color: McTint.display,
                    title: s.t('startScan'),
                    nav: OneRowNav.none,
                    onTap: c.connecting
                        ? null
                        : () {
                            Navigator.pop(context);
                            c.connect(scan: true);
                          },
                  ),
                  if (c.ble.connected)
                    OneRow(
                      icon: Icons.link_off,
                      color: McTint.advanced,
                      title: s.t('disconnectAction'),
                      nav: OneRowNav.none,
                      onTap: () {
                        Navigator.pop(context);
                        c.disconnect();
                      },
                    ),
                  OneRow(
                    icon: Icons.visibility_outlined,
                    color: McTint.identity,
                    title: s.t('previewContinue'),
                    nav: OneRowNav.none,
                    onTap: () {
                      Navigator.pop(context);
                      c.enterPreview();
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  s.t('browserNotice'),
                  style: const TextStyle(
                    color: McColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _LocaleField extends StatelessWidget {
  const _LocaleField({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            controller.i18n.t('language'),
            style: const TextStyle(color: McColors.muted, fontSize: 12),
          ),
        ),
        DropdownButton<String>(
          value: controller.i18n.locale,
          isExpanded: true,
          dropdownColor: McColors.panel,
          items: [
            for (final code in S.supported)
              DropdownMenuItem(value: code, child: Text(S.names[code] ?? code)),
          ],
          onChanged: (v) {
            if (v != null) controller.setLocale(v);
          },
        ),
      ],
    );
  }
}

class _LeadingSwitch extends StatelessWidget {
  const _LeadingSwitch({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final home = controller.isHome;
    return SizedBox(
      width: 40,
      height: 40,
      child: AnimatedSwitcher(
        duration: _kNavDuration,
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.82, end: 1).animate(curved),
              child: child,
            ),
          );
        },
        child: home
            ? const BrandMark(key: ValueKey('mark'), size: 36)
            : OneCircleButton(
                key: const ValueKey('back'),
                icon: Icons.arrow_back,
                tooltip: controller.i18n.t('back'),
                onPressed: controller.back,
              ),
      ),
    );
  }
}

const _kNavDuration = Duration(milliseconds: 300);

class _RouteSwitcher extends StatefulWidget {
  const _RouteSwitcher({required this.controller});
  final AppController controller;

  @override
  State<_RouteSwitcher> createState() => _RouteSwitcherState();
}

class _RouteSwitcherState extends State<_RouteSwitcher> {
  late List<String> _alive;
  String? _incoming;
  String? _exiting;

  @override
  void initState() {
    super.initState();
    _alive = List<String>.of(widget.controller.navigationStack);
  }

  @override
  void didUpdateWidget(covariant _RouteSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = List<String>.of(widget.controller.navigationStack);
    if (listEquals(next, _alive)) return;
    if (widget.controller.navForward &&
        (next.length > _alive.length || next.last != _alive.last)) {
      _incoming = next.last;
      _exiting = null;
    } else {
      _exiting = _alive.isEmpty ? null : _alive.last;
      _incoming = null;
    }
    _alive = next;
  }

  void _finishIn(String route) {
    if (!mounted || _incoming != route) return;
    setState(() => _incoming = null);
  }

  void _finishOut(String route) {
    if (!mounted || _exiting != route) return;
    setState(() => _exiting = null);
  }

  @override
  Widget build(BuildContext context) {
    final top = _alive.isEmpty ? 'home' : _alive.last;
    final under = _alive.length >= 2 ? _alive[_alive.length - 2] : null;
    final layers = <String>[
      for (final route in _alive) route,
      if (_exiting != null && !_alive.contains(_exiting)) _exiting!,
    ];
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final route in layers)
            Positioned.fill(
              key: ValueKey(route),
              child: _RouteLayer(
                route: route,
                controller: widget.controller,
                hidden: route != top &&
                    route != _exiting &&
                    !(_incoming != null && route == under),
                recede: _incoming != null && route == under,
                slide: route == _incoming
                    ? _RouteSlide.incoming
                    : route == _exiting
                        ? _RouteSlide.outgoing
                        : _RouteSlide.none,
                onInComplete: () => _finishIn(route),
                onOutComplete: () => _finishOut(route),
              ),
            ),
        ],
      ),
    );
  }
}

enum _RouteSlide { none, incoming, outgoing }

class _RouteLayer extends StatefulWidget {
  const _RouteLayer({
    required this.route,
    required this.controller,
    required this.hidden,
    required this.recede,
    required this.slide,
    required this.onInComplete,
    required this.onOutComplete,
  });

  final String route;
  final AppController controller;
  final bool hidden;
  final bool recede;
  final _RouteSlide slide;
  final VoidCallback onInComplete;
  final VoidCallback onOutComplete;

  @override
  State<_RouteLayer> createState() => _RouteLayerState();
}

class _RouteLayerState extends State<_RouteLayer>
    with TickerProviderStateMixin {
  late final AnimationController _slide;
  late final AnimationController _recede;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(vsync: this, duration: _kNavDuration);
    _recede = AnimationController(vsync: this, duration: _kNavDuration);
    if (widget.slide == _RouteSlide.incoming) {
      _slide.forward(from: 0).whenComplete(() {
        if (mounted &&
            widget.slide == _RouteSlide.incoming &&
            _slide.isCompleted) {
          widget.onInComplete();
        }
      });
    } else {
      _slide.value = 1;
    }
    if (widget.recede) {
      _recede.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant _RouteLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.slide == _RouteSlide.outgoing &&
        oldWidget.slide != _RouteSlide.outgoing) {
      _slide.reverse().whenComplete(() {
        if (mounted &&
            widget.slide == _RouteSlide.outgoing &&
            _slide.isDismissed) {
          widget.onOutComplete();
        }
      });
    }
    if (widget.hidden && !oldWidget.hidden) {
      _recede.value = 1;
    } else if (!widget.hidden && oldWidget.hidden) {
      _recede.reverse();
    } else if (widget.recede && !oldWidget.recede) {
      _recede.forward();
    } else if (!widget.recede && oldWidget.recede && !widget.hidden) {
      _recede.reverse();
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    _recede.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slideAnim = CurvedAnimation(
      parent: _slide,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );
    final recedeAnim = CurvedAnimation(
      parent: _recede,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );
    return Offstage(
      offstage: widget.hidden,
      child: IgnorePointer(
        ignoring: widget.hidden || widget.slide == _RouteSlide.outgoing,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(slideAnim),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.2, 0),
            ).animate(recedeAnim),
            child: TickerMode(
              enabled: !widget.hidden,
              child: SizedBox.expand(
                child: ColoredBox(
                  color: McColors.bg,
                  child: _Router(
                    controller: widget.controller,
                    route: widget.route,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Router extends StatelessWidget {
  const _Router({required this.controller, required this.route});
  final AppController controller;
  final String route;

  @override
  Widget build(BuildContext context) {
    if (route.startsWith('card-detail/')) {
      return _CardDetail(
        controller: controller,
        index: int.tryParse(route.split('/').last) ?? -1,
      );
    }
    switch (route) {
      case 'media-image':
        return _MediaPage(controller: controller, animation: false);
      case 'media-animation':
        return _MediaPage(controller: controller, animation: true);
      case 'device-settings':
        return _ControlPage(controller: controller);
      case 'card':
        return _ProfilePage(controller: controller);
      case 'tags':
        return _TagsPage(controller: controller);
      case 'carousel':
        return _CarouselPage(controller: controller);
      case 'received-cards':
        return _CardsPage(controller: controller);
      case 'device-info':
        return _DeviceInfoPage(controller: controller);
      case 'file-transfer':
        return _FilePage(controller: controller);
      case 'ota-update':
        return _OtaPage(controller: controller);
      case 'settings':
        return _SettingsPage(controller: controller);
      case 'diagnostics':
        return _DiagnosticsPage(controller: controller);
      case 'docs':
        return _DocsPage(controller: controller);
      default:
        return _HomePage(controller: controller);
    }
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.controller,
    required this.title,
    required this.child,
  });
  final AppController controller;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: PageStorageKey<String>('page-$title'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: [OneUiTitle(title), const SizedBox(height: 8), child],
    );
  }
}

class McCard extends StatelessWidget {
  const McCard({super.key, required this.child, this.onTap, this.padding});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: McColors.panel,
        borderRadius: BorderRadius.circular(26),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: body,
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.i18n;
    final d = controller.device;
    return HoloBackdrop(
      child: ListView(
        key: const PageStorageKey<String>('home'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
        children: [
          OneUiTitle(
            controller.ble.connected
                ? (d?.name ?? s.t('passName'))
                : s.t('passName'),
            subtitle: controller.ble.connected
                ? [
                    s.t('connected'),
                    if (d?.battery != null) '${d!.battery}%',
                    d?.firmwareVersion,
                  ].whereType<String>().join('  ·  ')
                : s.t('slogan'),
          ),
          DeviceHero(online: controller.ble.connected),
          const SizedBox(height: 8),
          if (controller.previewDevice) ...[
            const SizedBox(height: 8),
            OneGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Text(
                    s.t('previewBanner'),
                    style: const TextStyle(
                      height: 1.45,
                      color: McColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (d == null)
            OneGroup(
              children: [
                OneRow(
                  icon: Icons.bluetooth_searching,
                  color: McTint.display,
                  title: s.t('startScan'),
                  subtitle: s.t('tapToConnect'),
                  nav: OneRowNav.sheet,
                  onTap: () => showConnectSheet(context, controller),
                ),
                OneRow(
                  icon: Icons.visibility_outlined,
                  color: McTint.identity,
                  title: s.t('previewContinue'),
                  nav: OneRowNav.none,
                  onTap: controller.enterPreview,
                ),
              ],
            )
          else ...[
            _SectionLabel(s.t('sectionDisplay')),
            OneGroup(
              children: [
                OneRow(
                  icon: Icons.image_outlined,
                  color: McTint.display,
                  title: s.t('image'),
                  subtitle: s.t('imageDesc'),
                  onTap: () => controller.go('media-image'),
                ),
                OneRow(
                  icon: Icons.animation,
                  color: McTint.display,
                  title: s.t('animation'),
                  subtitle: s.t('animationDesc'),
                  onTap: () => controller.go('media-animation'),
                ),
                OneRow(
                  icon: Icons.view_carousel_outlined,
                  color: McTint.display,
                  title: s.t('carousel'),
                  subtitle: s.t('carouselDesc'),
                  onTap: () => controller.go('carousel'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(s.t('sectionIdentity')),
            OneGroup(
              children: [
                OneRow(
                  icon: Icons.badge_outlined,
                  color: McTint.identity,
                  title: s.t('profile'),
                  subtitle: s.t('profileDesc'),
                  onTap: () => controller.go('card'),
                ),
                OneRow(
                  icon: Icons.sell_outlined,
                  color: McTint.identity,
                  title: s.t('tags'),
                  subtitle: s.t('tagsDesc'),
                  onTap: () => controller.go('tags'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(s.t('sectionInbox')),
            OneGroup(
              children: [
                OneRow(
                  icon: Icons.mail_outlined,
                  color: McTint.inbox,
                  title: s.t('receivedCards'),
                  subtitle: controller.cards.isEmpty
                      ? s.t('receivedCardsDesc')
                      : '${controller.cards.length}',
                  onTap: () => controller.go('received-cards'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(s.t('sectionDevice')),
            OneGroup(
              children: [
                OneRow(
                  icon: Icons.tune,
                  color: McTint.device,
                  title: s.t('deviceControl'),
                  subtitle: s.t('deviceControlDesc'),
                  onTap: () => controller.go('device-settings'),
                ),
                OneRow(
                  icon: Icons.info_outline,
                  color: McTint.device,
                  title: s.t('deviceInfo'),
                  subtitle: [
                    if (d.battery != null) '${s.t('battery')} ${d.battery}%',
                    if (d.storage != null) d.storage,
                    s.t('deviceInfoDesc'),
                  ].join(' · '),
                  onTap: () => controller.go('device-info'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(s.t('sectionAdvanced')),
            OneGroup(
              children: [
                OneRow(
                  icon: Icons.swap_vert,
                  color: McTint.advanced,
                  title: s.t('fileTransfer'),
                  subtitle: s.t('fileTransferDesc'),
                  onTap: () => controller.go('file-transfer'),
                ),
                OneRow(
                  icon: Icons.system_update_alt,
                  color: McTint.advanced,
                  title: s.t('otaUpdate'),
                  subtitle: s.t('otaUpdateDesc'),
                  onTap: () => controller.go('ota-update'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 8, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: McColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MediaPage extends StatefulWidget {
  const _MediaPage({required this.controller, required this.animation});
  final AppController controller;
  final bool animation;
  @override
  State<_MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<_MediaPage> {
  Uint8List? bytes;
  Uint8List? cropped;
  String name = '';
  String mime = '';
  StillCrop crop = const StillCrop();
  MotionClip motion = const MotionClip();
  String status = '';
  double progress = 0;
  Uint8List? preview;
  String? path;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: widget.animation ? FileType.custom : FileType.image,
      allowedExtensions: widget.animation
          ? const ['gif', 'mp4', 'mov', 'm4v', 'webm']
          : null,
    );
    if (!mounted) return;
    final file = result?.files.single;
    if (file == null) return;
    final data = await loadPickedBytes(file.bytes, file.path);
    if (!mounted || data == null) return;
    final motionFile =
        widget.animation || looksLikeMotion(file.name, file.extension ?? '');
    try {
      if (motionFile) {
        final edited = await showMotionEditor(
          context,
          bytes: data,
          name: file.name,
          mime: file.extension ?? '',
          path: file.path,
          i18n: widget.controller.i18n,
        );
        if (edited == null || !mounted) return;
        setState(() {
          bytes = data;
          cropped = edited.mp4;
          crop = edited.clip.crop;
          motion = edited.clip;
          name = file.name;
          mime = file.extension ?? '';
          path = file.path;
          preview = edited.preview;
          status =
              '${file.name} · 240×320 · ${edited.frames}f · ${(edited.mp4.length / 1024).round()} KB';
        });
        return;
      }
      final edited = await showStillCropEditor(
        context,
        bytes: data,
        i18n: widget.controller.i18n,
      );
      if (edited == null || !mounted) return;
      setState(() {
        bytes = data;
        cropped = edited.png;
        crop = edited.crop;
        name = file.name;
        mime = file.extension ?? '';
        path = file.path;
        preview = edited.png;
        status =
            '${file.name} · 240×320 · ${(edited.png.length / 1024).round()} KB';
      });
    } on MotionVideoUnsupported {
      widget.controller.showToast(
        widget.controller.i18n.t('motionUnsupported'),
      );
    } catch (e) {
      widget.controller.showToast(widget.controller.i18n.t('decodeError'));
    }
  }

  Future<void> _editCrop() async {
    final source = bytes;
    final c = widget.controller;
    if (source == null) {
      c.showToast(c.i18n.t('chooseFirst'));
      return;
    }
    try {
      if (widget.animation || looksLikeMotion(name, mime)) {
        final edited = await showMotionEditor(
          context,
          bytes: source,
          name: name,
          mime: mime,
          path: path,
          i18n: c.i18n,
        );
        if (edited == null || !mounted) return;
        setState(() {
          cropped = edited.mp4;
          crop = edited.clip.crop;
          motion = edited.clip;
          preview = edited.preview;
          status =
              '$name · 240×320 · ${edited.frames}f · ${(edited.mp4.length / 1024).round()} KB';
        });
        return;
      }
      final edited = await showStillCropEditor(
        context,
        bytes: source,
        i18n: c.i18n,
        initial: crop,
      );
      if (edited == null || !mounted) return;
      setState(() {
        cropped = edited.png;
        crop = edited.crop;
        preview = edited.png;
        status = '$name · 240×320 · ${(edited.png.length / 1024).round()} KB';
      });
    } on MotionVideoUnsupported {
      c.showToast(c.i18n.t('motionUnsupported'));
    } catch (e) {
      c.showToast(c.i18n.t('decodeError'));
    }
  }

  Future<void> _send() async {
    final c = widget.controller;
    final source = bytes;
    if (source == null) {
      c.showToast(c.i18n.t('chooseFirst'));
      return;
    }
    if (!c.ble.connected) {
      c.showToast(c.i18n.t('needConnect'));
      return;
    }
    final isMotion = widget.animation || looksLikeMotion(name, mime);
    try {
      setState(() => status = c.i18n.t('converting'));
      Uint8List payload;
      if (isMotion) {
        payload =
            cropped ??
            (await prepareMotion(
              source,
              name: name,
              mime: mime,
              path: path,
              clip: motion,
            )).mp4;
      } else {
        payload = cropped ?? prepareStill(source, crop: crop);
      }
      if (!mounted) return;
      final ok = await showRiskDialog(
        context,
        c,
        kind: 'FILE',
        fileName: name,
        bytes: payload.length,
      );
      if (!ok || !mounted) return;
      final deviceName = deviceResourceName(motion: isMotion);
      final result = await c.transfer.sendFile(
        payload,
        name: deviceName,
        onProgress: (p) => setState(() {
          progress = p / 100;
          status = c.i18n.t('sending', {'p': '$p'});
        }),
      );
      setState(() {
        progress = 1;
        status = c.i18n.t('done', {
          'bytes': '${result.bytes}',
          'packets': '${result.packets}',
          'crc': result.crc32hex,
        });
      });
    } on MotionVideoUnsupported {
      setState(() => status = c.i18n.t('motionUnsupported'));
      c.showToast(c.i18n.t('motionUnsupported'));
    } catch (e) {
      setState(() => status = e.toString());
      c.showToast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return _Page(
      controller: c,
      title: c.i18n.t(widget.animation ? 'animation' : 'image'),
      child: McCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 240,
                height: 320,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: preview == null
                    ? Text(
                        c.i18n.t('noMedia'),
                        style: const TextStyle(color: McColors.muted),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.memory(
                          preview!,
                          width: 240,
                          height: 320,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _pick,
                  child: Text(
                    c.i18n.t(
                      widget.animation ? 'chooseAnimation' : 'chooseImage',
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: _editCrop,
                  child: Text(
                    c.i18n.t(widget.animation ? 'motionTitle' : 'cropEdit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () {
                    if (bytes == null) {
                      c.showToast(c.i18n.t('chooseFirst'));
                      return;
                    }
                    final ready = cropped ?? bytes!;
                    setState(
                      () => status =
                          '$name · ${(ready.length / 1024).round()} KB',
                    );
                  },
                  child: Text(c.i18n.t('inspectMedia')),
                ),
                ElevatedButton(
                  onPressed: _send,
                  child: Text(
                    c.i18n.t(widget.animation ? 'sendMotion' : 'sendStill'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              color: McColors.accent,
              backgroundColor: McColors.panel2,
            ),
            const SizedBox(height: 8),
            Text(status, style: const TextStyle(color: McColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _ControlPage extends StatelessWidget {
  const _ControlPage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.i18n;
    final rows = [
      ('broadcast', s.t('broadcast')),
      ('buzzer', s.t('buzzer')),
      ('vibration', s.t('vibration')),
      ('interestLight', s.t('interestLight')),
      ('interestScan', s.t('interestScan')),
      ('ambient', s.t('ambient')),
    ];
    bool value(String key) {
      switch (key) {
        case 'broadcast':
          return controller.settings.broadcast;
        case 'buzzer':
          return controller.settings.buzzer;
        case 'vibration':
          return controller.settings.vibration;
        case 'interestLight':
          return controller.settings.interestLight;
        case 'interestScan':
          return controller.settings.interestScan;
        default:
          return controller.settings.ambient;
      }
    }

    return _Page(
      controller: controller,
      title: s.t('deviceControl'),
      child: McCard(
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => controller.refreshRuntime(),
                  child: Text(s.t('readSettings')),
                ),
                ElevatedButton(
                  onPressed: () =>
                      _guard(context, controller, controller.writeSettings),
                  child: Text(s.t('writeSettings')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final row in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(row.$2),
                trailing: Switch(
                  value: value(row.$1),
                  activeThumbColor: McColors.ink,
                  activeTrackColor: McColors.accent,
                  onChanged: (_) => controller.toggleSetting(row.$1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.i18n;
    final count = utf8Bytes(controller.profile).length;
    return _Page(
      controller: controller,
      title: s.t('editProfile'),
      child: McCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton(
              onPressed: () =>
                  _guard(context, controller, controller.readProfile),
              child: Text(s.t('readSettings')),
            ),
            const SizedBox(height: 12),
            Text(
              s.t('profileContent'),
              style: const TextStyle(color: McColors.muted),
            ),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: controller.profile,
              minLines: 6,
              maxLines: 10,
              onChanged: controller.updateProfile,
            ),
            const SizedBox(height: 6),
            Text(
              '$count / ${Limits.cardBytes} bytes',
              style: TextStyle(
                color: count > Limits.cardBytes
                    ? McColors.danger
                    : McColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  _guard(context, controller, controller.saveProfile),
              child: Text(s.t('saveSync')),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagsPage extends StatefulWidget {
  const _TagsPage({required this.controller});
  final AppController controller;
  @override
  State<_TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<_TagsPage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.i18n;
    final cats = c.catalog?.categories(s.locale) ?? const <TagCategory>[];
    TagCategory? current;
    if (cats.isNotEmpty) {
      current = cats.firstWhere(
        (e) => e.id == c.tagCategoryId,
        orElse: () => cats.first,
      );
    }
    final matches = query.trim().isEmpty
        ? const <TagItem>[]
        : (c.catalog?.search(query, s.locale) ?? const <TagItem>[]);
    Widget chip(TagItem tag) {
      final on = c.selectedTags.any((t) => t.key == tag.key);
      return FilterChip(
        selected: on,
        label: Text(
          tag.official ? tag.label : '${tag.label} · ${s.t('unofficial')}',
        ),
        selectedColor: McColors.accent,
        labelStyle: TextStyle(
          color: on ? McColors.ink : McColors.text,
          fontSize: 13,
        ),
        backgroundColor: McColors.panel2,
        onSelected: (_) => c.toggleTag(tag.ref),
      );
    }

    return _Page(
      controller: c,
      title: s.t('chooseTags'),
      child: McCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.t('tagPolicy'),
              style: const TextStyle(color: Color(0xFFFFF7A7), height: 1.45),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${s.t('selected')} ${c.selectedTags.length} / ${Limits.tags}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: c.clearSelectedTags,
                  child: Text(s.t('clearTags')),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (c.selectedTags.isEmpty)
                  Text(
                    s.t('noTags'),
                    style: const TextStyle(color: McColors.muted),
                  ),
                for (final ref in c.selectedTags)
                  chip(
                    c.catalog?.find(ref.category, ref.tagId, s.locale) ??
                        TagItem(
                          category: ref.category,
                          tagId: ref.tagId,
                          label: ref.key,
                          official: false,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(hintText: s.t('searchTags')),
              onChanged: (v) => setState(() => query = v),
            ),
            if (matches.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final t in matches) chip(t)],
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in cats)
                  ChoiceChip(
                    selected: cat.id == current?.id,
                    label: Text(
                      '${cat.label} ${cat.tags.length}${cat.official ? '' : ' · ${s.t('unofficial')}'}',
                    ),
                    selectedColor: McColors.accent,
                    labelStyle: TextStyle(
                      color: cat.id == current?.id
                          ? McColors.ink
                          : McColors.text,
                    ),
                    onSelected: (_) => c.setTagCategory(cat.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (current != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final t in current.tags) chip(t)],
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _guard(context, c, c.saveTags),
              child: Text(s.t('saveTags')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselPage extends StatefulWidget {
  const _CarouselPage({required this.controller});
  final AppController controller;
  @override
  State<_CarouselPage> createState() => _CarouselPageState();
}

class _CarouselPageState extends State<_CarouselPage> {
  late final TextEditingController seconds;
  String status = '';
  double progress = 0;

  @override
  void initState() {
    super.initState();
    seconds = TextEditingController(
      text: '${widget.controller.settings.carouselSeconds}',
    );
  }

  @override
  void dispose() {
    seconds.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final c = widget.controller;
    if (!c.ble.connected) {
      c.showToast(c.i18n.t('needConnect'));
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
      type: FileType.media,
    );
    final files = result?.files.where((f) => f.bytes != null).toList() ?? [];
    if (files.isEmpty) {
      c.showToast(c.i18n.t('chooseFirst'));
      return;
    }
    final secs = int.tryParse(seconds.text) ?? 5;
    try {
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        setState(() => status = '${i + 1}/${files.length} ${file.name}');
        final motion = looksLikeMotion(file.name, file.extension ?? '');
        Uint8List payload;
        if (motion) {
          payload = (await prepareMotion(
            file.bytes!,
            name: file.name,
            mime: file.extension ?? '',
            path: file.path,
          )).mp4;
        } else {
          payload = prepareStill(file.bytes!);
        }
        if (!mounted) return;
        final ok = await showRiskDialog(
          context,
          c,
          kind: 'FILE',
          fileName: file.name,
          bytes: payload.length,
        );
        if (!ok || !mounted) return;
        await c.transfer.sendFile(
          payload,
          name: deviceResourceName(motion: motion),
          onProgress: (p) =>
              setState(() => progress = (i + p / 100) / files.length),
        );
      }
      await c.writeCarousel(secs.clamp(1, 60));
      setState(
        () => status = c.i18n.t('done', {
          'bytes': '${files.length}',
          'packets': '$secs',
          'crc': 'ok',
        }),
      );
    } catch (e) {
      setState(() => status = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return _Page(
      controller: c,
      title: c.i18n.t('carousel'),
      child: McCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _guard(context, c, () async {
                    final res = await c.request(
                      readCarousel(),
                      ControlCommand.respCarouselRd,
                    );
                    c.settings.carouselSeconds = readU16(res.data, 0);
                    c.settings.carousel = c.settings.carouselSeconds > 0;
                    seconds.text = '${c.settings.carouselSeconds}';
                    c.touch();
                  }),
                  child: Text(c.i18n.t('readSettings')),
                ),
                OutlinedButton(
                  onPressed: () => _guard(context, c, () async {
                    await c.writeCarousel(0);
                    c.showToast(c.i18n.t('carouselOff'));
                  }),
                  child: Text(c.i18n.t('disableCarousel')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              c.i18n.t('carouselInterval'),
              style: const TextStyle(color: McColors.muted),
            ),
            TextField(controller: seconds, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress == 0 ? null : progress,
              color: McColors.accent,
              backgroundColor: McColors.panel2,
            ),
            const SizedBox(height: 8),
            Text(status, style: const TextStyle(color: McColors.muted)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _send,
              child: Text(c.i18n.t('enableCarousel')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardsPage extends StatelessWidget {
  const _CardsPage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.i18n;
    return _Page(
      controller: controller,
      title: s.t('receivedCards'),
      child: McCard(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () => _guard(context, controller, () async {
                await controller.ble.send(
                  control(ControlCommand.readCardsCount),
                );
                controller.showToast(
                  controller.i18n.t('commandSent', {
                    'label': s.t('receivedCards'),
                  }),
                );
              }),
              child: Text(s.t('readCardCount')),
            ),
            const SizedBox(height: 12),
            if (controller.cards.isEmpty)
              Text(
                s.t('noCachedCards'),
                style: const TextStyle(color: McColors.muted),
              )
            else
              for (var i = 0; i < controller.cards.length; i++)
                ListTile(
                  title: Text(controller.cards[i].title),
                  subtitle: Text(controller.cards[i].receivedAt),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => controller.go('card-detail/$i'),
                ),
          ],
        ),
      ),
    );
  }
}

class _CardDetail extends StatelessWidget {
  const _CardDetail({required this.controller, required this.index});
  final AppController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final s = controller.i18n;
    if (index < 0 || index >= controller.cards.length) {
      return _Page(
        controller: controller,
        title: s.t('cardDetails'),
        child: Text(s.t('notFound')),
      );
    }
    final card = controller.cards[index];
    return _Page(
      controller: controller,
      title: s.t('cardDetails'),
      child: McCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(card.detail),
            const SizedBox(height: 8),
            Text(
              card.receivedAt,
              style: const TextStyle(color: McColors.muted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B2029),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                controller.cards.removeAt(index);
                controller.persist();
                controller.go('received-cards');
              },
              child: Text(s.t('deleteCard')),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceInfoPage extends StatelessWidget {
  const _DeviceInfoPage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.i18n;
    final d = controller.device;
    return _Page(
      controller: controller,
      title: s.t('deviceInfo'),
      child: McCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProductPair(),
            const SizedBox(height: 16),
            Text(
              s.t('deviceName'),
              style: const TextStyle(color: McColors.muted),
            ),
            TextFormField(
              initialValue: d?.name ?? '',
              onChanged: (v) {
                controller.device?.name = v;
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                controller.persist();
                controller.showToast(s.t('localOnlyName'));
              },
              child: Text(s.t('saveName')),
            ),
            const SizedBox(height: 16),
            _kv(s.t('serial'), d?.serial ?? '--'),
            _kv(s.t('softwareVersion'), d?.firmwareVersion ?? '--'),
            _kv(s.t('battery'), d?.battery == null ? '--' : '${d!.battery}%'),
            _kv(s.t('fileSystem'), d?.storage ?? '--'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => controller.refreshRuntime(),
              child: Text(s.t('refreshDevice')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(k, style: const TextStyle(color: McColors.muted)),
          ),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _FilePage extends StatefulWidget {
  const _FilePage({required this.controller});
  final AppController controller;
  @override
  State<_FilePage> createState() => _FilePageState();
}

class _FilePageState extends State<_FilePage> {
  PlatformFile? file;
  int fileType = FileTypeId.resource;
  String status = '';
  double progress = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return _Page(
      controller: c,
      title: c.i18n.t('fileTransfer'),
      child: McCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Warn(c.i18n.t('disclaimerFileBody')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final r = await FilePicker.platform.pickFiles(withData: true);
                if (r?.files.single.bytes != null)
                  setState(() => file = r!.files.single);
              },
              child: Text(c.i18n.t('chooseImage')),
            ),
            if (file != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${file!.name} · ${((file!.size) / 1024).round()} KB',
                ),
              ),
            const SizedBox(height: 12),
            Text(
              c.i18n.t('fileType'),
              style: const TextStyle(color: McColors.muted),
            ),
            DropdownButton<int>(
              value: fileType,
              dropdownColor: McColors.panel,
              items: const [
                DropdownMenuItem(value: 1, child: Text('RESOURCE')),
                DropdownMenuItem(value: 2, child: Text('IP')),
                DropdownMenuItem(value: 3, child: Text('PURCHASE')),
                DropdownMenuItem(value: 4, child: Text('UI')),
              ],
              onChanged: (v) => setState(() => fileType = v ?? 1),
            ),
            LinearProgressIndicator(
              value: progress == 0 ? 0 : progress,
              color: McColors.accent,
              backgroundColor: McColors.panel2,
            ),
            Text(status, style: const TextStyle(color: McColors.muted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    if (file?.bytes == null) {
                      c.showToast(c.i18n.t('chooseFirst'));
                      return;
                    }
                    if (!c.ble.connected) {
                      c.showToast(c.i18n.t('needConnect'));
                      return;
                    }
                    final ok = await showRiskDialog(
                      context,
                      c,
                      kind: 'FILE',
                      fileName: file!.name,
                      bytes: file!.bytes!.length,
                    );
                    if (!ok) return;
                    try {
                      final result = await c.transfer.sendFile(
                        file!.bytes!,
                        name: file!.name,
                        fileType: fileType,
                        onProgress: (p) => setState(() {
                          progress = p / 100;
                          status = c.i18n.t('sending', {'p': '$p'});
                        }),
                      );
                      setState(
                        () => status = c.i18n.t('done', {
                          'bytes': '${result.bytes}',
                          'packets': '${result.packets}',
                          'crc': result.crc32hex,
                        }),
                      );
                    } catch (e) {
                      setState(() => status = e.toString());
                    }
                  },
                  child: Text(c.i18n.t('startTransfer')),
                ),
                OutlinedButton(
                  onPressed: c.transfer.abort,
                  child: Text(c.i18n.t('abort')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FileTypeId {
  static const resource = 1;
}

class _OtaPage extends StatefulWidget {
  const _OtaPage({required this.controller});
  final AppController controller;
  @override
  State<_OtaPage> createState() => _OtaPageState();
}

class _OtaPageState extends State<_OtaPage> {
  PlatformFile? file;
  int imageId = 0;
  String status = '';
  double progress = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return _Page(
      controller: c,
      title: c.i18n.t('otaUpdate'),
      child: McCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Warn(c.i18n.t('disclaimerOtaBody')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final r = await FilePicker.platform.pickFiles(withData: true);
                if (r?.files.single.bytes != null)
                  setState(() => file = r!.files.single);
              },
              child: Text(c.i18n.t('firmwareImage')),
            ),
            if (file != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(file!.name),
              ),
            const SizedBox(height: 8),
            Text(
              c.i18n.t('imageId'),
              style: const TextStyle(color: McColors.muted),
            ),
            TextField(
              keyboardType: TextInputType.number,
              onChanged: (v) => imageId = int.tryParse(v) ?? 0,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress == 0 ? 0 : progress,
              color: McColors.danger,
              backgroundColor: McColors.panel2,
            ),
            Text(status, style: const TextStyle(color: McColors.muted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B2029),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (file?.bytes == null) {
                      c.showToast(c.i18n.t('chooseFirst'));
                      return;
                    }
                    if (!c.ble.connected) {
                      c.showToast(c.i18n.t('needConnect'));
                      return;
                    }
                    final ok = await showRiskDialog(
                      context,
                      c,
                      kind: 'OTA',
                      fileName: file!.name,
                      bytes: file!.bytes!.length,
                    );
                    if (!ok) return;
                    try {
                      final result = await c.transfer.sendOta(
                        file!.bytes!,
                        imageId: imageId,
                        onProgress: (p) => setState(() {
                          progress = p / 100;
                          status = c.i18n.t('sending', {'p': '$p'});
                        }),
                      );
                      setState(
                        () => status = c.i18n.t('done', {
                          'bytes': '${result.bytes}',
                          'packets': '${result.packets}',
                          'crc': result.crc32hex,
                        }),
                      );
                    } catch (e) {
                      setState(() => status = e.toString());
                    }
                  },
                  child: Text(c.i18n.t('startOta')),
                ),
                OutlinedButton(
                  onPressed: c.transfer.abort,
                  child: Text(c.i18n.t('abort')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.i18n;
    return ListView(
      key: const PageStorageKey<String>('settings'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: [
        OneUiTitle(s.t('appSettings')),
        const SizedBox(height: 8),
        OneGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: _LocaleField(controller: controller),
            ),
          ],
        ),
        const SizedBox(height: 20),
        OneGroup(
          children: [
            OneRow(
              icon: Icons.monitor_heart_outlined,
              color: McTint.device,
              title: s.t('diagnostics'),
              subtitle: s.t('advanced'),
              onTap: () => controller.go('diagnostics'),
            ),
            OneRow(
              icon: Icons.menu_book_outlined,
              color: McTint.identity,
              title: s.t('documentation'),
              subtitle: s.t('docsIntro'),
              onTap: () => controller.go('docs'),
            ),
          ],
        ),
        if (controller.device != null) ...[
          const SizedBox(height: 20),
          OneGroup(
            children: [
              OneRow(
                icon: Icons.delete_outline,
                color: McColors.danger,
                title: s.t('forgetDevice'),
                onTap: controller.forget,
                nav: OneRowNav.none,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DiagnosticsPage extends StatelessWidget {
  const _DiagnosticsPage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.i18n;
    return _Page(
      controller: controller,
      title: s.t('diagnostics'),
      child: McCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: controller.connect,
                  child: Text(s.t('diagConnect')),
                ),
                OutlinedButton(
                  onPressed: () => _guard(context, controller, () async {
                    final r = await controller.request(
                      getVersion(),
                      ControlCommand.respVersion,
                    );
                    controller.showToast(decodeText(r.data));
                  }),
                  child: Text(s.t('sendVersion')),
                ),
                OutlinedButton(
                  onPressed: () => _guard(context, controller, () async {
                    final r = await controller.request(
                      getBattery(),
                      ControlCommand.respBattery,
                    );
                    controller.showToast('${readU16(r.data, 0)}%');
                  }),
                  child: Text(s.t('sendBattery')),
                ),
                OutlinedButton(
                  onPressed: () => _guard(context, controller, () async {
                    await controller.request(
                      getFileSystemInfo(),
                      ControlCommand.getFsInfoResponse,
                    );
                    controller.showToast(s.t('refreshOk'));
                  }),
                  child: Text(s.t('sendFs')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: controller.clearLogs,
              child: Text(s.t('clearLog')),
            ),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF080A0F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: McColors.line),
              ),
              child: Text(
                controller.logs
                    .map((e) => '${e.time} ${e.message} ${e.data ?? ''}')
                    .join('\n'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocsPage extends StatelessWidget {
  const _DocsPage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    const body = '''
GATT
• Service  7369666c-695f-7364-0000-000000000000
• Data     7369666c-695f-7364-0002-000000000000

Frame
• category u8 · flags u8 · payload_length u16 LE · payload

CONTROL 0x1F
GET_VERSION 20 · GET_BATTERY 22 · GET_SERIAL 18 · GET_FS 32
SET_CARD_INFO 14 / READ 16 · SET_TAGS 34
CONTROL_INFO 24 · SET_CAROUSEL 42 / READ 44

FILE 0x04 and OTA 0x01 stay behind an explicit acknowledgement.
Profile text is capped at 319 UTF-8 bytes. Tags are capped at 5.
''';
    return _Page(
      controller: controller,
      title: controller.i18n.t('documentation'),
      child: McCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.i18n.t('docsIntro'),
              style: const TextStyle(color: McColors.muted),
            ),
            const SizedBox(height: 12),
            const Text(
              body,
              style: TextStyle(
                fontFamily: 'monospace',
                height: 1.5,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Warn extends StatelessWidget {
  const _Warn(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x295B2029),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF8F3A48)),
      ),
      child: Text(text, style: const TextStyle(height: 1.45)),
    );
  }
}

Future<void> _guard(
  BuildContext context,
  AppController c,
  Future<void> Function() run,
) async {
  try {
    await run();
  } catch (e) {
    c.showToast(e.toString());
  }
}

Future<bool> showRiskDialog(
  BuildContext context,
  AppController c, {
  required String kind,
  required String fileName,
  required int bytes,
}) async {
  final isOta = kind == 'OTA';
  var checked = false;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setSt) {
              return AlertDialog(
                backgroundColor: const Color(0xFF131722),
                title: Text(
                  c.i18n.t(
                    isOta ? 'disclaimerOtaTitle' : 'disclaimerFileTitle',
                  ),
                ),
                content: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.i18n.t(
                          isOta ? 'disclaimerOtaBody' : 'disclaimerFileBody',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('• ${c.i18n.t('risk1')}'),
                      Text('• ${c.i18n.t('risk2')}'),
                      Text('• ${c.i18n.t('risk3')}'),
                      const SizedBox(height: 8),
                      Text(
                        '$fileName (${(bytes / 1024).ceil()} KB)',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      CheckboxListTile(
                        value: checked,
                        onChanged: (v) => setSt(() => checked = v ?? false),
                        title: Text(c.i18n.t('confirmRisk')),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(c.i18n.t('cancel')),
                  ),
                  ElevatedButton(
                    style: isOta
                        ? ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B2029),
                            foregroundColor: Colors.white,
                          )
                        : null,
                    onPressed: checked
                        ? () => Navigator.pop(context, true)
                        : null,
                    child: Text(c.i18n.t(isOta ? 'startOta' : 'startTransfer')),
                  ),
                ],
              );
            },
          );
        },
      ) ??
      false;
}
