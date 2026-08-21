import 'package:flutter/material.dart';

import 'api.dart';

const kCaseTypes = ['complaint', 'bug', 'feedback', 'request', 'ticket'];

const kPalette = [
  '#007AFF',
  '#FF9500',
  '#FF3B30',
  '#34C759',
  '#5856D6',
  '#5AC8FA',
  '#AF52DE',
  '#8E8E93',
];

class WorkspaceStore extends ChangeNotifier {
  WorkspaceStore(this.api);

  final Api api;
  List workspaces = [];
  bool loading = false;
  String? error;

  Map<String, dynamic>? byId(String id) {
    for (final w in workspaces) {
      if (w['id'] == id) return Map<String, dynamic>.from(w as Map);
    }
    return null;
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      workspaces = await api.get('/api/workspaces') as List;
    } catch (e) {
      error = e.toString();
      workspaces = [];
    }
    loading = false;
    notifyListeners();
  }

  Future<Map> create({required String name, String description = ''}) async {
    final created = await api.post('/api/workspaces', {'name': name, 'description': description}) as Map;
    await load();
    return created;
  }

  Future<void> save(String id, Map body) async {
    await api.patch('/api/workspaces/$id', body);
    await load();
  }

  void clear() {
    workspaces = [];
    error = null;
    notifyListeners();
  }
}

List<Map<String, dynamic>> categoryMaps(Map? ws) {
  final raw = ws?['categories'] as List? ?? [];
  return [
    for (final c in raw)
      c is String
          ? {'id': c, 'label': c, 'color': '#007AFF'}
          : Map<String, dynamic>.from(c as Map),
  ];
}

List<Map<String, dynamic>> tagMaps(Map? ws) {
  final raw = ws?['tags'] as List? ?? [];
  return [
    for (final t in raw)
      t is String ? {'id': t, 'label': t} : Map<String, dynamic>.from(t as Map),
  ];
}

List<String> enabledTypes(Map? ws) {
  final ct = Map<String, dynamic>.from(ws?['caseTypes'] as Map? ?? {});
  return [for (final t in kCaseTypes) if (ct[t] != false) t];
}

Color parseHex(String? hex, [Color fallback = const Color(0xFF007AFF)]) {
  if (hex == null || hex.isEmpty) return fallback;
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  if (v == null) return fallback;
  return Color(v);
}
