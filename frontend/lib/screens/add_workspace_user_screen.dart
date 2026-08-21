import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth_state.dart';
import '../roles.dart';
import '../paths.dart';
import '../theme.dart';
import '../widgets.dart';
import '../workspace_store.dart';
import '../workspace_switcher.dart';

class AddWorkspaceUserScreen extends StatefulWidget {
  const AddWorkspaceUserScreen({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  State<AddWorkspaceUserScreen> createState() => _AddWorkspaceUserScreenState();
}

class _AddWorkspaceUserScreenState extends State<AddWorkspaceUserScreen> {
  List rows = [];
  List<Map<String, dynamic>> members = [];
  String role = 'customer';
  String? selectedId;
  String? error;
  bool loading = true;
  bool busy = false;
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic>? _member(String userId) {
    for (final m in members) {
      if (m['userId'] == userId) return m;
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final store = context.read<WorkspaceStore>();
    final api = context.read<Api>();
    try {
      await store.load();
      final q = search.text.trim();
      final list = await api.get('/api/users', {
        'workspaceId': widget.workspaceId,
        if (q.isNotEmpty) 'q': q,
      }) as List;
      if (!mounted) return;
      setState(() {
        rows = list;
        members = memberMaps(store.byId(widget.workspaceId));
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  List<Map> get _sortedRows {
    final available = <Map>[];
    final added = <Map>[];
    for (final u in rows) {
      if (_member(u['id'] as String) != null) {
        added.add(u);
      } else {
        available.add(u);
      }
    }
    return [...available, ...added];
  }

  Future<void> _submit() async {
    if (selectedId == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final store = context.read<WorkspaceStore>();
      final ws = store.byId(widget.workspaceId);
      final members = [...memberMaps(ws), {'userId': selectedId, 'role': role}];
      await store.save(widget.workspaceId, {'members': members});
      if (!mounted) return;
      context.go(wspaceUsers(widget.workspaceId));
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final roleOptions = assignableWorkspaceRoles(isAppOperator: auth.isAppOperator);
    if (!roleOptions.contains(role)) role = roleOptions.first;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 88,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.go(wspaceUsers(widget.workspaceId)),
          child: const Text('Cancel'),
        ),
        title: const Text('Add User'),
        actions: topBarActions(context, workspaceId: widget.workspaceId),
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          children: [
            if (error != null) IosErrorBanner(error!),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: CupertinoSearchTextField(
                controller: search,
                placeholder: 'Search user master…',
                onSubmitted: (_) => _load(),
              ),
            ),
            if (loading) const LoadingBody(),
            if (!loading)
              InsetGroup(
                header: 'Select user',
                footer: 'Users already in this workspace appear faded below.',
                children: [
                  if (_sortedRows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No users found.', style: TextStyle(color: Color(0xFF8E8E93))),
                    ),
                  for (final u in _sortedRows)
                    Builder(
                      builder: (_) {
                        final id = u['id'] as String;
                        final member = _member(id);
                        final inWorkspace = member != null;
                        final tile = RadioListTile<String>(
                          value: id,
                          groupValue: selectedId,
                          title: Text(
                            u['name'] as String? ?? u['username'] as String? ?? '',
                            style: TextStyle(color: inWorkspace ? iosSecondary : iosLabel),
                          ),
                          subtitle: Text(
                            inWorkspace
                                ? '${u['username']} · ${u['email']} · ${workspaceRoleLabel(member['role'] as String)}'
                                : '${u['username']} · ${u['email']}',
                            style: TextStyle(color: inWorkspace ? iosTertiary : iosSecondary),
                          ),
                          onChanged: inWorkspace ? null : (v) => setState(() => selectedId = v),
                        );
                        return Opacity(opacity: inWorkspace ? 0.45 : 1, child: tile);
                      },
                    ),
                ],
              ),
            if (!loading)
              InsetGroup(
                header: 'Workspace role',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(role),
                      initialValue: role,
                      decoration: iosInput('Role'),
                      items: [
                        for (final r in roleOptions)
                          DropdownMenuItem(value: r, child: Text(workspaceRoleLabel(r))),
                      ],
                      onChanged: (v) => setState(() => role = v as String),
                    ),
                  ),
                ],
              ),
            if (!loading)
              IosPrimaryButton(
                label: busy ? 'Adding…' : 'Add to workspace',
                onPressed: busy || selectedId == null ? null : _submit,
              ),
          ],
        ),
      ),
    );
  }
}
