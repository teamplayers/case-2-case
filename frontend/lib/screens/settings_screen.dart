import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import '../widgets.dart';
import '../workspace_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final name = TextEditingController();
  final description = TextEditingController();
  final tagInput = TextEditingController();
  Map<String, bool> types = {for (final t in kCaseTypes) t: true};
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> tags = [];
  String? error;
  bool saved = false;
  bool addingTag = false;
  String? _hydratedId;

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    tagInput.dispose();
    super.dispose();
  }

  void _hydrate(Map w) {
    name.text = w['name'] as String? ?? '';
    description.text = w['description'] as String? ?? '';
    types = {for (final t in kCaseTypes) t: (w['caseTypes'] as Map?)?[t] != false};
    categories = categoryMaps(w);
    tags = tagMaps(w);
    _hydratedId = widget.workspaceId;
  }

  Future<void> _save({bool show = true}) async {
    setState(() {
      error = null;
      saved = false;
    });
    try {
      await context.read<WorkspaceStore>().save(widget.workspaceId, {
        'name': name.text.trim(),
        'description': description.text.trim(),
        'caseTypes': types,
        'categories': categories,
        'tags': tags,
      });
      if (show) setState(() => saved = true);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final w = store.byId(widget.workspaceId);
    if (w == null) {
      if (store.loading) return const LoadingBody();
      return const IosEmpty(icon: CupertinoIcons.square_grid_2x2, title: 'Workspace not found', message: 'Pick another space from the top.');
    }
    if (_hydratedId != widget.workspaceId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final current = context.read<WorkspaceStore>().byId(widget.workspaceId);
        if (current != null) setState(() => _hydrate(current));
      });
      return const LoadingBody();
    }
    return SafeArea(
      child: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            const LargeTitle('Settings', subtitle: 'Workspace name, allowed types, categories, and tags.'),
            if (error != null) IosErrorBanner(error!),
            if (saved)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Saved.', style: TextStyle(color: iosGreen)),
              ),
            InsetGroup(
              header: 'Basic info',
              children: [
                TextField(controller: name, decoration: iosInput('Name')),
                TextField(controller: description, decoration: iosInput('Description'), maxLines: 3),
              ],
            ),
            InsetGroup(
              header: 'Case types',
              footer: 'Enable types this workspace can file. Complaint audio is only available when Complaint is on.',
              children: [
                for (final t in kCaseTypes)
                  SwitchListTile.adaptive(
                    title: Text(typeLabel(t)),
                    value: types[t] ?? true,
                    onChanged: (on) => setState(() => types[t] = on),
                  ),
              ],
            ),
            InsetGroup(
              header: 'Categories',
              footer: 'Each case picks one. Tap a swatch to change color.',
              children: [
                for (var i = 0; i < categories.length; i++)
                  _CategoryRow(
                    category: categories[i],
                    onChanged: (c) => setState(() => categories[i] = c),
                    onDelete: () => setState(() => categories.removeAt(i)),
                  ),
                IosCell(
                  title: 'Add category',
                  trailing: const Icon(CupertinoIcons.plus_circle_fill, color: iosBlue),
                  onTap: () => setState(() {
                    categories.add({
                      'id': 'cat-${DateTime.now().millisecondsSinceEpoch}',
                      'label': 'New category',
                      'color': kPalette[categories.length % kPalette.length],
                    });
                  }),
                ),
              ],
            ),
            InsetGroup(
              header: 'Tags',
              children: [
                for (var i = 0; i < tags.length; i++)
                  IosCell(
                    title: tags[i]['label'] as String? ?? '',
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(() => tags.removeAt(i)),
                      child: const Icon(CupertinoIcons.trash, size: 20, color: iosRed),
                    ),
                  ),
                if (addingTag)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(child: TextField(controller: tagInput, decoration: iosInput('Tag name'), autofocus: true)),
                        CupertinoButton(
                          onPressed: () {
                            final label = tagInput.text.trim();
                            if (label.isEmpty) return;
                            setState(() {
                              tags.add({'id': 'tag-${DateTime.now().millisecondsSinceEpoch}', 'label': label});
                              tagInput.clear();
                              addingTag = false;
                            });
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                IosCell(
                  title: 'Add tag',
                  trailing: const Icon(CupertinoIcons.plus_circle_fill, color: iosBlue),
                  onTap: () => setState(() => addingTag = true),
                ),
              ],
            ),
            IosPrimaryButton(label: 'Save', onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.onChanged, required this.onDelete});
  final Map<String, dynamic> category;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = parseHex(category['color'] as String?);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          PopupMenuButton<String>(
            onSelected: (hex) => onChanged({...category, 'color': hex}),
            itemBuilder: (context) => [
              for (final hex in kPalette)
                PopupMenuItem(
                  value: hex,
                  child: Row(
                    children: [
                      Container(width: 18, height: 18, decoration: BoxDecoration(color: parseHex(hex), shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(hex),
                    ],
                  ),
                ),
            ],
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: iosGray4)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              initialValue: category['label'] as String? ?? '',
              decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Label'),
              onChanged: (v) => onChanged({...category, 'label': v}),
            ),
          ),
          IconButton(onPressed: onDelete, icon: const Icon(CupertinoIcons.trash, size: 18, color: iosRed)),
        ],
      ),
    );
  }
}
