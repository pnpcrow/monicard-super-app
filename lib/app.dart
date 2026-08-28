import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controller.dart';
import 'l10n.dart';
import 'media.dart';
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
        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 840;
                return Row(
                  children: [
                    if (wide) _Sidebar(controller: c),
                    Expanded(
                      child: Column(
                        children: [
                          _Topbar(controller: c, compact: !wide),
                          Expanded(child: _Router(controller: c)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          bottomNavigationBar: LayoutBuilder(
            builder: (context, box) {
              if (box.maxWidth >= 840) return const SizedBox.shrink();
              return _MobileNav(controller: c);
            },
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0E14),
        border: Border(right: BorderSide(color: McColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Brand(),
          const SizedBox(height: 28),
          _NavButtons(controller: controller, vertical: true),
          const Spacer(),
          _LocaleField(controller: controller),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 36 : 44,
          height: compact ? 36 : 44,
          decoration: BoxDecoration(
            color: McColors.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.badge_outlined, color: McColors.ink),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MoniCard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              Text('Super', style: TextStyle(color: McColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Topbar extends StatelessWidget {
  const _Topbar({required this.controller, required this.compact});
  final AppController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final d = controller.device;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          if (compact) const Expanded(child: _Brand(compact: true)) else const Spacer(),
          if (d != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10141C),
                border: Border.all(color: McColors.line),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  _Dot(online: controller.ble.connected),
                  const SizedBox(width: 8),
                  Text(d.name, style: const TextStyle(color: McColors.muted, fontSize: 13)),
                ],
              ),
            ),
          if (compact) ...[
            const SizedBox(width: 8),
            SizedBox(width: 120, child: _LocaleField(controller: controller, compact: true)),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.online});
  final bool online;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? McColors.ok : const Color(0xFF697080),
        boxShadow: online ? const [BoxShadow(color: McColors.ok, blurRadius: 10)] : null,
      ),
    );
  }
}

class _LocaleField extends StatelessWidget {
  const _LocaleField({required this.controller, this.compact = false});
  final AppController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(controller.i18n.t('language'), style: const TextStyle(color: McColors.muted, fontSize: 12)),
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

class _NavButtons extends StatelessWidget {
  const _NavButtons({required this.controller, required this.vertical});
  final AppController controller;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    Widget item(String route, String label) {
      final on = route == 'settings'
          ? controller.route == 'settings' || controller.route == 'diagnostics' || controller.route == 'docs'
          : controller.route != 'settings' && controller.route != 'diagnostics' && controller.route != 'docs';
      return TextButton(
        onPressed: () => controller.go(route),
        style: TextButton.styleFrom(
          alignment: vertical ? Alignment.centerLeft : Alignment.center,
          foregroundColor: on ? McColors.accent : McColors.muted,
          backgroundColor: on ? McColors.panel2 : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        child: Text(label),
      );
    }

    final children = [
      item('home', controller.i18n.t('devices')),
      item('settings', controller.i18n.t('settings')),
    ];
    if (vertical) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    return Row(children: [for (final c in children) Expanded(child: c)]);
  }
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xEE0B0E14),
        border: Border(top: BorderSide(color: McColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: _NavButtons(controller: controller, vertical: false),
    );
  }
}

class _Router extends StatelessWidget {
  const _Router({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final route = controller.route;
    if (route.startsWith('card-detail/')) {
      return _CardDetail(controller: controller, index: int.tryParse(route.split('/').last) ?? -1);
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
  const _Page({required this.controller, required this.title, required this.child});
  final AppController controller;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => controller.go('home'),
            child: Text('← ${controller.i18n.t('back')}', style: const TextStyle(color: McColors.text)),
          ),
        ),
        Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1.05)),
        const SizedBox(height: 16),
        child,
      ],
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
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF171B25), Color(0xFF10131A)],
        ),
        border: Border.all(color: McColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: body),
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
    final features = <(String, String, String, IconData)>[
      ('image', s.t('imageDesc'), 'media-image', Icons.image_outlined),
      ('animation', s.t('animationDesc'), 'media-animation', Icons.animation),
      ('carousel', s.t('carouselDesc'), 'carousel', Icons.view_carousel_outlined),
      ('profile', s.t('profileDesc'), 'card', Icons.badge_outlined),
      ('tags', s.t('tagsDesc'), 'tags', Icons.sell_outlined),
      ('deviceControl', s.t('deviceControlDesc'), 'device-settings', Icons.tune),
      ('receivedCards', s.t('receivedCardsDesc'), 'received-cards', Icons.mail_outlined),
      ('deviceInfo', s.t('deviceInfoDesc'), 'device-info', Icons.info_outline),
      ('fileTransfer', s.t('fileTransferDesc'), 'file-transfer', Icons.swap_vert),
      ('otaUpdate', s.t('otaUpdateDesc'), 'ota-update', Icons.system_update_alt),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        Text(s.t('safeMode').toUpperCase(), style: const TextStyle(color: McColors.accent, letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(d == null ? s.t('connectTitle') : s.t('connectedTitle'), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: -1.6, height: 1.02)),
        const SizedBox(height: 10),
        Text(d == null ? s.t('connectDesc') : s.t('connectedDesc'), style: const TextStyle(color: McColors.muted, height: 1.5)),
        const SizedBox(height: 8),
        Text(s.t('demoNotice'), style: const TextStyle(color: McColors.muted, height: 1.45, fontSize: 13)),
        const SizedBox(height: 18),
        if (d == null)
          McCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('addDevice'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: controller.connect, child: Text(s.t('startScan'))),
                const SizedBox(height: 12),
                Text(s.t('browserNotice'), style: const TextStyle(color: McColors.muted, height: 1.45)),
              ],
            ),
          )
        else ...[
          McCard(
            child: Row(
              children: [
                _Dot(online: controller.ble.connected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(
                        '${controller.ble.connected ? s.t('connected') : s.t('savedOffline')} · ${d.firmwareVersion ?? s.t('unknownVersion')}',
                        style: const TextStyle(color: McColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(onPressed: controller.connect, child: Text(s.t('reconnect'))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth >= 900 ? 3 : (box.maxWidth >= 560 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  for (final f in features)
                    McCard(
                      onTap: () => controller.go(f.$3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(f.$4, color: McColors.accent, size: 28),
                          const Spacer(),
                          Text(s.t(f.$1), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(f.$2, style: const TextStyle(color: McColors.muted, fontSize: 13, height: 1.35)),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
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
  String name = '';
  String mime = '';
  double zoom = 1;
  String status = '';
  double progress = 0;
  Uint8List? preview;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: widget.animation ? FileType.custom : FileType.image,
      allowedExtensions: widget.animation ? const ['gif', 'mp4', 'mov', 'm4v', 'webm'] : null,
    );
    final file = result?.files.single;
    if (file?.bytes == null) return;
    setState(() {
      bytes = file!.bytes;
      name = file.name;
      mime = file.extension ?? '';
      preview = looksLikeMotion(file.name, mime) ? null : file.bytes;
      status = '${file.name} · ${((file.size) / 1024).round()} KB';
    });
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
    final motion = widget.animation || looksLikeMotion(name, mime);
    try {
      setState(() => status = c.i18n.t('converting'));
      Uint8List payload = source;
      if (!motion) payload = prepareStill(source, zoom: zoom);
      final ok = await showRiskDialog(context, c, kind: 'FILE', fileName: name, bytes: payload.length);
      if (!ok || !mounted) return;
      final deviceName = deviceResourceName(motion: motion);
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
        status = c.i18n.t('done', {'bytes': '${result.bytes}', 'packets': '${result.packets}', 'crc': result.crc32hex});
      });
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
                  color: const Color(0xFF090C11),
                  border: Border.all(color: const Color(0xFF3D4655), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: preview == null
                    ? Text(c.i18n.t('noMedia'), style: const TextStyle(color: McColors.muted))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Transform.scale(
                          scale: zoom,
                          child: Image.memory(preview!, width: 240, height: 320, fit: BoxFit.cover),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: _pick, child: Text(c.i18n.t(widget.animation ? 'chooseAnimation' : 'chooseImage'))),
            if (!widget.animation) ...[
              const SizedBox(height: 12),
              Text(c.i18n.t('zoom'), style: const TextStyle(color: McColors.muted)),
              Slider(value: zoom, min: 1, max: 3, onChanged: (v) => setState(() => zoom = v)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () {
                    if (bytes == null) {
                      c.showToast(c.i18n.t('chooseFirst'));
                      return;
                    }
                    setState(() => status = '$name · ${(bytes!.length / 1024).round()} KB');
                  },
                  child: Text(c.i18n.t('inspectMedia')),
                ),
                ElevatedButton(onPressed: _send, child: Text(c.i18n.t(widget.animation ? 'sendMotion' : 'sendStill'))),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress, color: McColors.accent, backgroundColor: McColors.panel2),
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
                OutlinedButton(onPressed: () => controller.refreshRuntime(), child: Text(s.t('readSettings'))),
                ElevatedButton(
                  onPressed: () => _guard(context, controller, controller.writeSettings),
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
            OutlinedButton(onPressed: () => _guard(context, controller, controller.readProfile), child: Text(s.t('readSettings'))),
            const SizedBox(height: 12),
            Text(s.t('profileContent'), style: const TextStyle(color: McColors.muted)),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: controller.profile,
              minLines: 6,
              maxLines: 10,
              onChanged: controller.updateProfile,
            ),
            const SizedBox(height: 6),
            Text('$count / ${Limits.cardBytes} bytes', style: TextStyle(color: count > Limits.cardBytes ? McColors.danger : McColors.muted)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _guard(context, controller, controller.saveProfile), child: Text(s.t('saveSync'))),
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
      current = cats.firstWhere((e) => e.id == c.tagCategoryId, orElse: () => cats.first);
    }
    final matches = query.trim().isEmpty ? const <TagItem>[] : (c.catalog?.search(query, s.locale) ?? const <TagItem>[]);
    Widget chip(TagItem tag) {
      final on = c.selectedTags.any((t) => t.key == tag.key);
      return FilterChip(
        selected: on,
        label: Text(tag.official ? tag.label : '${tag.label} · ${s.t('unofficial')}'),
        selectedColor: McColors.accent,
        labelStyle: TextStyle(color: on ? McColors.ink : McColors.text, fontSize: 13),
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
            Text(s.t('tagPolicy'), style: const TextStyle(color: Color(0xFFFFF7A7), height: 1.45)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('${s.t('selected')} ${c.selectedTags.length} / ${Limits.tags}', style: const TextStyle(fontWeight: FontWeight.w700))),
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
                if (c.selectedTags.isEmpty) Text(s.t('noTags'), style: const TextStyle(color: McColors.muted)),
                for (final ref in c.selectedTags) chip(c.catalog?.find(ref.category, ref.tagId, s.locale) ?? TagItem(category: ref.category, tagId: ref.tagId, label: ref.key, official: false)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(hintText: s.t('searchTags')),
              onChanged: (v) => setState(() => query = v),
            ),
            if (matches.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final t in matches) chip(t)]),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in cats)
                  ChoiceChip(
                    selected: cat.id == current?.id,
                    label: Text('${cat.label} ${cat.tags.length}${cat.official ? '' : ' · ${s.t('unofficial')}'}'),
                    selectedColor: McColors.accent,
                    labelStyle: TextStyle(color: cat.id == current?.id ? McColors.ink : McColors.text),
                    onSelected: (_) => c.setTagCategory(cat.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (current != null) Wrap(spacing: 8, runSpacing: 8, children: [for (final t in current.tags) chip(t)]),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => _guard(context, c, c.saveTags), child: Text(s.t('saveTags'))),
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
    seconds = TextEditingController(text: '${widget.controller.settings.carouselSeconds}');
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
    final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true, type: FileType.media);
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
        final payload = motion ? file.bytes! : prepareStill(file.bytes!);
        final ok = await showRiskDialog(context, c, kind: 'FILE', fileName: file.name, bytes: payload.length);
        if (!ok || !mounted) return;
        await c.transfer.sendFile(
          payload,
          name: deviceResourceName(motion: motion),
          onProgress: (p) => setState(() => progress = (i + p / 100) / files.length),
        );
      }
      await c.writeCarousel(secs.clamp(1, 60));
      setState(() => status = c.i18n.t('done', {'bytes': '${files.length}', 'packets': '$secs', 'crc': 'ok'}));
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
                    final res = await c.request(readCarousel(), ControlCommand.respCarouselRd);
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
            Text(c.i18n.t('carouselInterval'), style: const TextStyle(color: McColors.muted)),
            TextField(controller: seconds, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress == 0 ? null : progress, color: McColors.accent, backgroundColor: McColors.panel2),
            const SizedBox(height: 8),
            Text(status, style: const TextStyle(color: McColors.muted)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _send, child: Text(c.i18n.t('enableCarousel'))),
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
                await controller.ble.send(control(ControlCommand.readCardsCount));
                controller.showToast(controller.i18n.t('commandSent', {'label': s.t('receivedCards')}));
              }),
              child: Text(s.t('readCardCount')),
            ),
            const SizedBox(height: 12),
            if (controller.cards.isEmpty)
              Text(s.t('noCachedCards'), style: const TextStyle(color: McColors.muted))
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
      return _Page(controller: controller, title: s.t('cardDetails'), child: Text(s.t('notFound')));
    }
    final card = controller.cards[index];
    return _Page(
      controller: controller,
      title: s.t('cardDetails'),
      child: McCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(card.detail),
            const SizedBox(height: 8),
            Text(card.receivedAt, style: const TextStyle(color: McColors.muted)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B2029), foregroundColor: Colors.white),
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
            Text(s.t('deviceName'), style: const TextStyle(color: McColors.muted)),
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
            ElevatedButton(onPressed: () => controller.refreshRuntime(), child: Text(s.t('refreshDevice'))),
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
          Expanded(child: Text(k, style: const TextStyle(color: McColors.muted))),
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
                if (r?.files.single.bytes != null) setState(() => file = r!.files.single);
              },
              child: Text(c.i18n.t('chooseImage')),
            ),
            if (file != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${file!.name} · ${((file!.size) / 1024).round()} KB')),
            const SizedBox(height: 12),
            Text(c.i18n.t('fileType'), style: const TextStyle(color: McColors.muted)),
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
            LinearProgressIndicator(value: progress == 0 ? 0 : progress, color: McColors.accent, backgroundColor: McColors.panel2),
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
                    final ok = await showRiskDialog(context, c, kind: 'FILE', fileName: file!.name, bytes: file!.bytes!.length);
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
                      setState(() => status = c.i18n.t('done', {'bytes': '${result.bytes}', 'packets': '${result.packets}', 'crc': result.crc32hex}));
                    } catch (e) {
                      setState(() => status = e.toString());
                    }
                  },
                  child: Text(c.i18n.t('startTransfer')),
                ),
                OutlinedButton(onPressed: c.transfer.abort, child: Text(c.i18n.t('abort'))),
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
                if (r?.files.single.bytes != null) setState(() => file = r!.files.single);
              },
              child: Text(c.i18n.t('firmwareImage')),
            ),
            if (file != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(file!.name)),
            const SizedBox(height: 8),
            Text(c.i18n.t('imageId'), style: const TextStyle(color: McColors.muted)),
            TextField(
              keyboardType: TextInputType.number,
              onChanged: (v) => imageId = int.tryParse(v) ?? 0,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress == 0 ? 0 : progress, color: McColors.danger, backgroundColor: McColors.panel2),
            Text(status, style: const TextStyle(color: McColors.muted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B2029), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (file?.bytes == null) {
                      c.showToast(c.i18n.t('chooseFirst'));
                      return;
                    }
                    if (!c.ble.connected) {
                      c.showToast(c.i18n.t('needConnect'));
                      return;
                    }
                    final ok = await showRiskDialog(context, c, kind: 'OTA', fileName: file!.name, bytes: file!.bytes!.length);
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
                      setState(() => status = c.i18n.t('done', {'bytes': '${result.bytes}', 'packets': '${result.packets}', 'crc': result.crc32hex}));
                    } catch (e) {
                      setState(() => status = e.toString());
                    }
                  },
                  child: Text(c.i18n.t('startOta')),
                ),
                OutlinedButton(onPressed: c.transfer.abort, child: Text(c.i18n.t('abort'))),
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text(s.t('appSettings'), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1.4)),
        const SizedBox(height: 16),
        McCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('language'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _LocaleField(controller: controller),
            ],
          ),
        ),
        const SizedBox(height: 12),
        McCard(
          onTap: () => controller.go('diagnostics'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('diagnostics'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text(s.t('advanced'), style: const TextStyle(color: McColors.muted)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        McCard(
          onTap: () => controller.go('docs'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('documentation'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text(s.t('docsIntro'), style: const TextStyle(color: McColors.muted)),
            ],
          ),
        ),
        if (controller.device != null) ...[
          const SizedBox(height: 12),
          McCard(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B2029), foregroundColor: Colors.white),
              onPressed: controller.forget,
              child: Text(s.t('forgetDevice')),
            ),
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
                ElevatedButton(onPressed: controller.connect, child: Text(s.t('diagConnect'))),
                OutlinedButton(
                  onPressed: () => _guard(context, controller, () async {
                    final r = await controller.request(getVersion(), ControlCommand.respVersion);
                    controller.showToast(decodeText(r.data));
                  }),
                  child: Text(s.t('sendVersion')),
                ),
                OutlinedButton(
                  onPressed: () => _guard(context, controller, () async {
                    final r = await controller.request(getBattery(), ControlCommand.respBattery);
                    controller.showToast('${readU16(r.data, 0)}%');
                  }),
                  child: Text(s.t('sendBattery')),
                ),
                OutlinedButton(
                  onPressed: () => _guard(context, controller, () async {
                    await controller.request(getFileSystemInfo(), ControlCommand.getFsInfoResponse);
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
              decoration: BoxDecoration(color: const Color(0xFF080A0F), borderRadius: BorderRadius.circular(12), border: Border.all(color: McColors.line)),
              child: Text(
                controller.logs.map((e) => '${e.time} ${e.message} ${e.data ?? ''}').join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
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
            Text(controller.i18n.t('docsIntro'), style: const TextStyle(color: McColors.muted)),
            const SizedBox(height: 12),
            const Text(body, style: TextStyle(fontFamily: 'monospace', height: 1.5, fontSize: 13)),
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

Future<void> _guard(BuildContext context, AppController c, Future<void> Function() run) async {
  try {
    await run();
  } catch (e) {
    c.showToast(e.toString());
  }
}

Future<bool> showRiskDialog(BuildContext context, AppController c, {required String kind, required String fileName, required int bytes}) async {
  final isOta = kind == 'OTA';
  final name = c.device?.name ?? 'MoniCard';
  var checked = false;
  var typed = '';
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setSt) {
              final ready = checked && typed == name;
              return AlertDialog(
                backgroundColor: const Color(0xFF131722),
                title: Text(c.i18n.t(isOta ? 'disclaimerOtaTitle' : 'disclaimerFileTitle')),
                content: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.i18n.t(isOta ? 'disclaimerOtaBody' : 'disclaimerFileBody')),
                      const SizedBox(height: 8),
                      Text('• ${c.i18n.t('risk1')}'),
                      Text('• ${c.i18n.t('risk2')}'),
                      Text('• ${c.i18n.t('risk3')}'),
                      const SizedBox(height: 8),
                      Text('$fileName (${(bytes / 1024).ceil()} KB)', style: const TextStyle(fontWeight: FontWeight.w700)),
                      CheckboxListTile(
                        value: checked,
                        onChanged: (v) => setSt(() => checked = v ?? false),
                        title: Text(c.i18n.t('confirmRisk')),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      Text(c.i18n.t('typeDeviceName')),
                      TextField(onChanged: (v) => setSt(() => typed = v)),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(c.i18n.t('cancel'))),
                  ElevatedButton(
                    style: isOta ? ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B2029), foregroundColor: Colors.white) : null,
                    onPressed: ready ? () => Navigator.pop(context, true) : null,
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
