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

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  Map<String, Map<String, dynamic>> userById = {};
  List<Map<String, dynamic>> members = [];
  String? error;
  bool loading = true;
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UsersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId) _load();
  }

  Map<String, dynamic> _userFor(String userId) {
    return userById[userId] ?? {'id': userId, 'username': userId, 'name': userId};
  }

  List<Map<String, dynamic>> get _filteredMembers {
    final q = search.text.trim().toLowerCase();
    if (q.isEmpty) return members;
    return [
      for (final m in members)
        if (_matchesQuery(_userFor(m['userId'] as String), q)) m,
    ];
  }

  bool _matchesQuery(Map<String, dynamic> user, String q) {
    final hay = '${user['name']} ${user['username']} ${user['email']}'.toLowerCase();
    return hay.contains(q);
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final api = context.read<Api>();
    final store = context.read<WorkspaceStore>();
    try {
      await store.load();
      final list = await api.get('/api/users', {'workspaceId': widget.workspaceId}) as List;
      if (!mounted) return;
      final ws = store.byId(widget.workspaceId);
      setState(() {
        userById = usersById(list);
        members = memberMaps(ws);
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _saveMembers() async {
    await context.read<WorkspaceStore>().save(widget.workspaceId, {
      'members': members,
    });
    await _load();
  }

  Future<void> _setRole(String userId, String role) async {
    setState(() {
      members.removeWhere((m) => m['userId'] == userId);
      members.add({'userId': userId, 'role': role});
    });
    await _saveMembers();
  }

  Future<void> _removeMember(String userId) async {
    setState(() => members.removeWhere((m) => m['userId'] == userId));
    await _saveMembers();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final ws = context.watch<WorkspaceStore>().byId(widget.workspaceId);
    final canManage = canManageWorkspaceMembers(ws, auth.id, appRole: auth.appRole);
    final roleOptions = assignableWorkspaceRoles(isAppOperator: auth.isAppOperator);
    return SafeArea(
      child: ContentWidth(
        child: ListView(
          children: [
            LargeTitle(
              'Users',
              subtitle: 'People assigned to this workspace.',
              actions: [
                if (canManage) AddAction(onPressed: () => context.go(wspaceAddUser(widget.workspaceId))),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: CupertinoSearchTextField(
                controller: search,
                placeholder: 'Search members…',
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (error != null) IosErrorBanner(error!),
            if (loading) const LoadingBody(),
            if (!loading)
              InsetGroup(
                header: 'Workspace members (${members.length})',
                children: [
                  if (_filteredMembers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        members.isEmpty ? 'No members yet.' : 'No members match your search.',
                        style: const TextStyle(color: Color(0xFF8E8E93)),
                      ),
                    ),
                  for (final m in _filteredMembers)
                    Builder(
                      builder: (_) {
                        final user = _userFor(m['userId'] as String);
                        final role = m['role'] as String;
                        return IosCell(
                          title: user['name'] as String? ?? user['username'] as String? ?? '',
                          subtitle: '${user['username']} · ${user['email'] ?? ''}',
                          trailing: canManage
                              ? Wrap(
                                  spacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    DropdownButton<String>(
                                      value: roleOptions.contains(role) ? role : roleOptions.first,
                                      underline: const SizedBox.shrink(),
                                      items: [
                                        for (final r in roleOptions)
                                          DropdownMenuItem(
                                            value: r,
                                            child: Text(workspaceRoleLabel(r)),
                                          ),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) _setRole(m['userId'] as String, v);
                                      },
                                    ),
                                    TextButton(
                                      onPressed: () => _removeMember(m['userId'] as String),
                                      child: const Text('Remove', style: TextStyle(color: iosRed)),
                                    ),
                                  ],
                                )
                              : IosBadge(workspaceRoleLabel(role), color: workspaceRoleTint(role)),
                        );
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
