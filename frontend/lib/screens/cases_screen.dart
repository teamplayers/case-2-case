import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../paths.dart';
import '../theme.dart';
import '../widgets.dart';
import '../workspace_store.dart';

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  State<CasesScreen> createState() => CasesScreenState();
}

class CasesScreenState extends State<CasesScreen> {
  List cases = [];
  String stage = '';
  String type = '';
  String search = '';
  final searchCtrl = TextEditingController();
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CasesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final q = <String, String>{'workspaceId': widget.workspaceId};
      if (stage.isNotEmpty) q['stage'] = stage;
      if (type.isNotEmpty) q['type'] = type;
      if (search.trim().isNotEmpty) q['q'] = search.trim();
      cases = await context.read<Api>().get('/api/cases', q) as List;
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WorkspaceStore>().byId(widget.workspaceId);
    final types = enabledTypes(ws);
    return SafeArea(
      bottom: false,
      child: ContentWidth(
        maxWidth: 860,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LargeTitle(
              'Cases',
              actions: [
                AddAction(onPressed: () => context.go(wspaceNewCase(widget.workspaceId))),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: searchCtrl,
                decoration: iosInput('Search title, description, transcript…'),
                onChanged: (v) {
                  search = v;
                  _load();
                },
              ),
            ),
            InsetGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('stage-$stage'),
                    initialValue: stage,
                    decoration: iosInput('Stage'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All stages')),
                      DropdownMenuItem(value: 'open', child: Text('Open')),
                      DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                      DropdownMenuItem(value: 'wip', child: Text('In progress')),
                      DropdownMenuItem(value: 'resolved', child: Text('Closed')),
                    ],
                    onChanged: (v) {
                      stage = v ?? '';
                      _load();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('type-$type'),
                    initialValue: type,
                    decoration: iosInput('Type'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Any type')),
                      for (final t in types) DropdownMenuItem(value: t, child: Text(typeLabel(t))),
                    ],
                    onChanged: (v) {
                      type = v ?? '';
                      _load();
                    },
                  ),
                ),
              ],
            ),
            if (error != null) IosErrorBanner(error!),
            const SizedBox(height: 12),
            Expanded(
              child: loading
                  ? const LoadingBody()
                  : cases.isEmpty
                      ? const IosEmpty(
                          icon: CupertinoIcons.tray,
                          title: 'No cases',
                          message: 'New cases in this workspace will show up here.',
                        )
                      : RefreshIndicator(
                          color: iosBlue,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.only(bottom: 32),
                            children: [
                              InsetGroup(
                                children: [
                                  for (final raw in cases)
                                    Builder(
                                      builder: (_) {
                                        final c = raw as Map;
                                        return IosCell(
                                          title: c['title'] as String? ?? '',
                                          subtitle: '${c['type'] ?? ''} · ${c['categoryLabel'] ?? c['category'] ?? ''}',
                                          trailing: Wrap(
                                            spacing: 6,
                                            children: [
                                              IosBadge(c['type'] as String? ?? '', color: typeTint(c['type'] as String? ?? '')),
                                              IosBadge(
                                                stageLabel(c['stage'] as String? ?? ''),
                                                color: stageTint(c['stage'] as String? ?? ''),
                                              ),
                                            ],
                                          ),
                                          onTap: () => context.go(wspaceCase(widget.workspaceId, c['id'] as String)),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
