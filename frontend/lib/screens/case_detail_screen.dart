import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth_state.dart';
import '../roles.dart';
import '../theme.dart';
import '../widgets.dart';
import '../workspace_store.dart';
import '../workspace_switcher.dart';

const nextStage = {'open': 'assigned', 'assigned': 'wip', 'wip': 'resolved'};

class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key, required this.id, required this.workspaceId});
  final String id;
  final String workspaceId;

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  Map? item;
  List agents = [];
  String? assigneeId;
  String? error;

  Api get api => context.read<Api>();
  AuthState get auth => context.read<AuthState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await api.get('/api/cases/${widget.id}') as Map;
      setState(() {
        item = data;
        assigneeId = data['assigneeId'] as String?;
      });
      if (canTriageCases(context.read<WorkspaceStore>().byId(widget.workspaceId), auth.id, appRole: auth.appRole)) {
        final users = await api.get('/api/users', {'workspaceId': widget.workspaceId}) as List;
        final ws = context.read<WorkspaceStore>().byId(widget.workspaceId);
        final triageRoles = {'admin', 'manager', 'agent'};
        setState(() {
          agents = [
            for (final u in users)
              if (memberMaps(ws).any((m) => m['userId'] == u['id'] && triageRoles.contains(m['role']))) u,
          ];
        });
      }
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> _run(Future<dynamic> Function() fn) async {
    try {
      final data = await fn();
      if (data is Map) setState(() => item = data);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = item;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Case')),
        body: Center(child: error == null ? const CupertinoActivityIndicator(radius: 12) : IosErrorBanner(error!)),
      );
    }
    final ai = Map<String, dynamic>.from(c['ai'] as Map? ?? {});
    final status = ai['status'] as String?;
    if (status != null && !{'done', 'failed'}.contains(status)) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) _load();
      });
    }
    final auth = context.watch<AuthState>();
    final ws = context.watch<WorkspaceStore>().byId(widget.workspaceId);
    final canTriage = canTriageCases(ws, auth.id, appRole: auth.appRole);
    final wsRole = workspaceRole(ws, auth.id);
    final next = nextStage[c['stage']];
    final tags = (c['tags'] as List? ?? []).join(', ');
    final isGuest = wsRole == 'guest';

    return Scaffold(
      appBar: AppBar(
        title: Text(c['title'] as String? ?? 'Case'),
        actions: topBarActions(context, workspaceId: widget.workspaceId),
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          children: [
            if (error != null) IosErrorBanner(error!),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  IosBadge(c['type'] as String? ?? '', color: typeTint(c['type'] as String? ?? '')),
                  IosBadge(stageLabel(c['stage'] as String? ?? ''), color: stageTint(c['stage'] as String? ?? '')),
                ],
              ),
            ),
            InsetGroup(
              header: 'Details',
              children: [
                if ((c['description'] as String? ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Text(c['description'] as String, style: const TextStyle(fontSize: 17, height: 1.4)),
                  ),
                IosCell(title: 'Category', trailing: Text(_meta(c['categoryLabel'] ?? c['category']), style: _trail)),
                IosCell(title: 'Tags', trailing: Text((c['tagLabels'] as List? ?? []).isEmpty ? (tags.isEmpty ? '—' : tags) : (c['tagLabels'] as List).join(', '), style: _trail, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
                IosCell(title: 'Reporter', trailing: Text(_meta(c['reporterName']), style: _trail)),
                IosCell(title: 'Assignee', trailing: Text(_meta(c['assigneeName'], empty: 'Unassigned'), style: _trail)),
              ],
            ),
            if (canTriage && c['canWork'] == true && !isGuest)
              InsetGroup(
                header: 'Triage',
                children: [
                  if (wsRole == 'admin' || wsRole == 'manager' || auth.isAppOperator)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(assigneeId),
                        initialValue: assigneeId,
                        decoration: iosInput('Assign to'),
                        items: [
                          for (final a in agents)
                            DropdownMenuItem(value: a['id'] as String, child: Text(a['name'] as String? ?? a['username'] as String? ?? '')),
                        ],
                        onChanged: (v) => setState(() => assigneeId = v),
                      ),
                    ),
                  IosCell(
                    leading: Icon((wsRole == 'admin' || wsRole == 'manager' || auth.isAppOperator) ? CupertinoIcons.person_badge_plus : CupertinoIcons.hand_raised, size: 20, color: iosBlue),
                    title: (wsRole == 'admin' || wsRole == 'manager' || auth.isAppOperator) ? 'Assign' : 'Take this case',
                    chevron: true,
                    onTap: () {
                      final target = (wsRole == 'admin' || wsRole == 'manager' || auth.isAppOperator) ? assigneeId : auth.id;
                      if (target == null) return;
                      _run(() => api.post('/api/cases/${widget.id}/assign', {'assigneeId': target}));
                    },
                  ),
                  if (next != null && c['stage'] != 'open')
                    IosCell(
                      leading: const Icon(CupertinoIcons.arrow_right_circle, size: 20, color: iosBlue),
                      title: 'Move to ${stageLabel(next)}',
                      chevron: true,
                      onTap: () => _run(() => api.post('/api/cases/${widget.id}/stage', {'stage': next})),
                    ),
                ],
              ),
            if (!isGuest) ...[
              InsetGroup(
                header: 'Conversation',
                children: [
                  IosCell(
                    leading: const Icon(CupertinoIcons.cloud_upload, size: 20, color: iosBlue),
                    title: 'Attach conversation',
                    chevron: true,
                    onTap: () async {
                      final picked = await FilePicker.platform.pickFiles(withData: true);
                      if (picked?.files.isEmpty ?? true) return;
                      await _run(() => api.upload('/api/cases/${widget.id}/audio', picked!.files.first));
                    },
                  ),
                  if (status != null) IosCell(title: 'Pipeline', trailing: IosBadge(status, color: _aiTint(status))),
                  if (ai['error'] != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Text('${ai['error']}', style: const TextStyle(color: iosRed, fontSize: 14)),
                    ),
                  if (canTriage && status == 'failed')
                    IosCell(
                      title: 'Retry job',
                      chevron: true,
                      onTap: () => _run(() => api.post('/api/cases/${widget.id}/audio/retry')),
                    ),
                ],
              ),
              for (final entry in (c['conversationLog'] as List? ?? []))
                if (entry is Map) ...[
                  if (entry['transcript'] != null) _block('Conversation log', entry['transcript'].toString()),
                  if (entry['translation'] != null && entry['translation'] != entry['transcript'])
                    _block('English translation', entry['translation'].toString()),
                ],
              if (ai['transcript'] != null && (c['conversationLog'] as List? ?? []).isEmpty)
                _block('Transcript', ai['transcript'].toString()),
              if (ai['translation'] != null && (c['conversationLog'] as List? ?? []).isEmpty)
                _block('English translation', ai['translation'].toString()),
              if (ai['summary'] != null) _block('Summary', ai['summary'].toString()),
              if (ai['suggestedCategory'] != null)
                InsetGroup(
                  header: 'Suggestion',
                  children: [
                    IosCell(
                      title: '${ai['suggestedCategory']}',
                      subtitle: 'Suggested category',
                      trailing: canTriage && c['category'] != ai['suggestedCategory']
                          ? CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _run(() => api.post('/api/cases/${widget.id}/apply-ai-category')),
                              child: const Text('Apply'),
                            )
                          : null,
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _block(String title, String body) {
    return InsetGroup(
      header: title,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: SelectableText(body, style: const TextStyle(fontSize: 15, height: 1.45, color: iosLabel)),
        ),
      ],
    );
  }

  static const _trail = TextStyle(fontSize: 16, color: iosSecondary);

  static String _meta(Object? v, {String empty = '—'}) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? empty : s;
  }

  static Color _aiTint(String status) {
    switch (status) {
      case 'done':
        return iosGreen;
      case 'failed':
        return iosRed;
      default:
        return iosOrange;
    }
  }
}
