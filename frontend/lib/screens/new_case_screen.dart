import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../paths.dart';
import '../theme.dart';
import '../widgets.dart';
import '../workspace_switcher.dart';
import '../workspace_store.dart';

class NewCaseScreen extends StatefulWidget {
  const NewCaseScreen({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  State<NewCaseScreen> createState() => _NewCaseScreenState();
}

class _NewCaseScreenState extends State<NewCaseScreen> {
  final title = TextEditingController();
  final description = TextEditingController();
  String? caseType;
  String? category;
  final tags = <String>{};
  PlatformFile? audio;
  String? error;
  bool busy = false;

  Map? get ws => context.read<WorkspaceStore>().byId(widget.workspaceId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final types = enabledTypes(ws);
      final cats = categoryMaps(ws);
      setState(() {
        caseType = types.isNotEmpty ? types.first : null;
        category = cats.isNotEmpty ? cats.first['id'] as String : null;
      });
    });
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (category == null || caseType == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    final api = context.read<Api>();
    final wid = widget.workspaceId;
    try {
      final created = await api.post('/api/cases', {
        'workspaceId': wid,
        'title': title.text.trim(),
        'description': description.text,
        'type': caseType,
        'category': category,
        'tags': tags.toList(),
      }) as Map;
      if (audio != null) {
        await api.upload('/api/cases/${created['id']}/audio', audio!);
      }
      if (!mounted) return;
      context.go(wspaceCase(wid, created['id'] as String));
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WorkspaceStore>().byId(widget.workspaceId);
    final types = enabledTypes(ws);
    final cats = categoryMaps(ws);
    final tagList = tagMaps(ws);
    final canSave = !busy && cats.isNotEmpty && title.text.trim().isNotEmpty && caseType != null;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 88,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.go(wspaceCases(widget.workspaceId)),
          child: const Text('Cancel'),
        ),
        title: const Text('New Case'),
        actions: topBarActions(context, workspaceId: widget.workspaceId),
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          children: [
            if (error != null) IosErrorBanner(error!),
            if (types.isNotEmpty)
              InsetGroup(
                header: 'Type',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(caseType),
                      initialValue: caseType ?? types.first,
                      decoration: iosInput('Case type'),
                      items: [for (final t in types) DropdownMenuItem(value: t, child: Text(typeLabel(t)))],
                      onChanged: (v) => setState(() => caseType = v),
                    ),
                  ),
                ],
              ),
            InsetGroup(
              header: 'Case',
              footer: cats.isEmpty ? 'Add categories in Settings first.' : null,
              children: [
                TextField(controller: title, decoration: iosInput('Title'), onChanged: (_) => setState(() {})),
                TextField(controller: description, decoration: iosInput('Description'), maxLines: 5, minLines: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(category),
                    initialValue: category,
                    decoration: iosInput('Category'),
                    items: [
                      for (final c in cats)
                        DropdownMenuItem(value: c['id'] as String, child: Text(c['label'] as String? ?? '')),
                    ],
                    onChanged: cats.isEmpty ? null : (v) => setState(() => category = v),
                  ),
                ),
              ],
            ),
            if (tagList.isNotEmpty)
              InsetGroup(
                header: 'Tags',
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in tagList)
                          FilterChip(
                            label: Text(t['label'] as String? ?? ''),
                            selected: tags.contains(t['id']),
                            showCheckmark: false,
                            selectedColor: iosBlue.withValues(alpha: 0.14),
                            onSelected: (on) => setState(() {
                              final id = t['id'] as String;
                              if (on) {
                                tags.add(id);
                              } else {
                                tags.remove(id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            InsetGroup(
              header: 'Conversation',
              footer: 'Optional. Audio is transcribed and attached as a log on the case.',
              children: [
                IosCell(
                  leading: const Icon(CupertinoIcons.mic, size: 20, color: iosBlue),
                  title: audio == null ? 'Attach conversation' : audio!.name,
                  chevron: true,
                  onTap: () async {
                    final picked = await FilePicker.platform.pickFiles(withData: true, type: FileType.any);
                    if (picked?.files.isNotEmpty == true) setState(() => audio = picked!.files.first);
                  },
                ),
              ],
            ),
            IosPrimaryButton(label: busy ? 'Saving…' : 'Create Case', onPressed: canSave ? _submit : null),
          ],
        ),
      ),
    );
  }
}
