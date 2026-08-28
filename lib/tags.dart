import 'dart:convert';

import 'package:flutter/services.dart';

import 'protocol.dart';

class TagItem {
  TagItem({
    required this.category,
    required this.tagId,
    required this.label,
    required this.official,
    this.empty = false,
    this.community = false,
    this.raw,
    this.unknown = false,
  });
  final int category;
  final int tagId;
  final String label;
  final bool official;
  final bool empty;
  final bool community;
  final String? raw;
  final bool unknown;
  String get key => '$category:$tagId';
  TagRef get ref => TagRef(category, tagId);
}

class TagCategory {
  TagCategory({
    required this.id,
    required this.categoryId,
    required this.label,
    required this.official,
    required this.tags,
  });
  final String id;
  final int categoryId;
  final String label;
  final bool official;
  final List<TagItem> tags;
}

class TagCatalog {
  TagCatalog._(this._official, this._community);
  final List<dynamic> _official;
  final List<dynamic> _community;
  static const communityStart = 192;

  static Future<TagCatalog> load() async {
    final raw = await rootBundle.loadString('assets/tags/tags_master.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return TagCatalog._(
      json['official'] as List<dynamic>? ?? const [],
      json['community'] as List<dynamic>? ?? const [],
    );
  }

  static const _locales = {'en', 'ja', 'zh', 'ko', 'ru'};

  String _text(dynamic names, String locale) {
    if (names is! Map) return '';
    final key = _locales.contains(locale) ? locale : 'en';
    return (names[key] ?? names['en'] ?? names['zh'] ?? names['ja'] ?? '').toString();
  }

  List<TagCategory> categories(String locale, {bool includeOfficial = true, bool includeCommunity = true}) {
    final out = <TagCategory>[];
    if (includeOfficial) {
      for (final c in _official) {
        final map = c as Map<String, dynamic>;
        final categoryId = map['categoryId'] as int;
        final items = (map['items'] as List<dynamic>? ?? const []);
        final tags = <TagItem>[];
        for (final item in items) {
          final m = item as Map<String, dynamic>;
          if (m['empty'] == true) continue;
          tags.add(TagItem(
            category: categoryId,
            tagId: m['tagId'] as int,
            label: _text(m['names'], locale),
            official: true,
            raw: m['raw']?.toString(),
          ));
        }
        out.add(TagCategory(
          id: 'official-$categoryId',
          categoryId: categoryId,
          label: _text(map['names'], locale),
          official: true,
          tags: tags,
        ));
      }
    }
    if (includeCommunity) {
      for (final c in _community) {
        final map = c as Map<String, dynamic>;
        final categoryId = map['categoryId'] as int;
        final items = (map['items'] as List<dynamic>? ?? const []);
        final tags = <TagItem>[];
        for (final item in items) {
          final m = item as Map<String, dynamic>;
          final ref = m['ref'] as Map<String, dynamic>? ?? m;
          final cat = (ref['category'] ?? m['category']) as int;
          final tagId = (ref['tagId'] ?? m['tagId']) as int;
          tags.add(TagItem(
            category: cat,
            tagId: tagId,
            label: _text(m['names'], locale),
            official: m['reusesOfficial'] == true,
            community: true,
          ));
        }
        out.add(TagCategory(
          id: 'community-$categoryId',
          categoryId: categoryId,
          label: _text(map['names'], locale),
          official: false,
          tags: tags,
        ));
      }
    }
    return out;
  }

  TagItem find(int category, int tagId, String locale) {
    for (final c in _official) {
      final map = c as Map<String, dynamic>;
      if (map['categoryId'] != category) continue;
      final items = map['items'] as List<dynamic>? ?? const [];
      for (final item in items) {
        final m = item as Map<String, dynamic>;
        if (m['tagId'] == tagId) {
          return TagItem(
            category: category,
            tagId: tagId,
            label: _text(m['names'], locale),
            official: true,
            empty: m['empty'] == true,
            raw: m['raw']?.toString(),
          );
        }
      }
    }
    for (final c in _community) {
      final map = c as Map<String, dynamic>;
      final items = map['items'] as List<dynamic>? ?? const [];
      for (final item in items) {
        final m = item as Map<String, dynamic>;
        if (m['ref'] != null) continue;
        if (m['category'] == category && m['tagId'] == tagId) {
          return TagItem(
            category: category,
            tagId: tagId,
            label: _text(m['names'], locale),
            official: false,
            community: true,
          );
        }
      }
    }
    return TagItem(category: category, tagId: tagId, label: 'Unknown tag ($category:$tagId)', official: false, unknown: true);
  }

  List<TagItem> search(String query, String locale, {int limit = 30}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final seen = <String>{};
    final result = <TagItem>[];
    for (final category in categories(locale)) {
      for (final tag in category.tags) {
        if (tag.empty || seen.contains(tag.key)) continue;
        final hay = '${tag.label} ${tag.raw ?? ''}'.toLowerCase();
        if (hay.contains(q)) {
          seen.add(tag.key);
          result.add(tag);
          if (result.length >= limit) return result;
        }
      }
    }
    return result;
  }
}
