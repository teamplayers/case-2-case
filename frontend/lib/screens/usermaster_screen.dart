import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth_state.dart';
import '../paths.dart';
import '../roles.dart';
import '../theme.dart';
import '../widgets.dart';

class UsermasterScreen extends StatefulWidget {
  const UsermasterScreen({super.key});

  @override
  State<UsermasterScreen> createState() => _UsermasterScreenState();
}

class _UsermasterScreenState extends State<UsermasterScreen> {
  List users = [];
  List pending = [];
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

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final api = context.read<Api>();
    try {
      final q = search.text.trim().isEmpty ? null : search.text.trim();
      final all = await api.get('/api/users', q == null ? null : {'q': q, 'approvedOnly': 'false'}) as List;
      final pend = await api.get('/api/users/pending') as List;
      if (!mounted) return;
      setState(() {
        users = all;
        pending = pend;
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _run(Future<void> Function() fn) async {
    try {
      await fn();
      await _load();
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> _setAppRole(Map user, String role) async {
    final id = user['id'] as String;
    final current = assignableAppRoleValue(user['appRole'] as String?);
    if (role == current) return;
    final api = context.read<Api>();
    if (role == 'superadmin') {
      await api.post('/api/users/$id/superadmin');
    } else {
      await api.delete('/api/users/$id/superadmin');
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return SafeArea(
      child: ContentWidth(
        maxWidth: 860,
        child: ListView(
          children: [
            LargeTitle(
              'Users',
              subtitle: 'Manage accounts, roles, and pending approvals.',
              actions: [
                AddAction(onPressed: () => context.go(cpUsersNew)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: CupertinoSearchTextField(
                controller: search,
                placeholder: 'Search username, name, email…',
                onSubmitted: (_) => _load(),
              ),
            ),
            if (error != null) IosErrorBanner(error!),
            if (loading) const LoadingBody(),
            if (!loading && pending.isNotEmpty)
              InsetGroup(
                header: 'Pending approval (${pending.length})',
                children: [
                  for (final u in pending)
                    IosCell(
                      title: u['name'] as String? ?? u['username'] as String? ?? '',
                      subtitle: '${u['username']} · ${u['email']}',
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IosBadge(userStatusLabel(u['status'] as String?), color: userStatusTint(u['status'] as String?)),
                          TextButton(
                            onPressed: () => _run(() => context.read<Api>().post('/api/users/${u['id']}/approve')),
                            child: const Text('Approve'),
                          ),
                          TextButton(
                            onPressed: () => _run(() => context.read<Api>().post('/api/users/${u['id']}/reject')),
                            child: const Text('Reject', style: TextStyle(color: iosRed)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            if (!loading)
              InsetGroup(
                header: 'All users (${users.length})',
                children: [
                  if (users.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No users found.', style: TextStyle(color: Color(0xFF8E8E93))),
                    ),
                  for (final u in users)
                    IosCell(
                      title: u['name'] as String? ?? u['username'] as String? ?? '',
                      subtitle: '${u['username']} · ${u['email']}',
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IosBadge(userStatusLabel(u['status'] as String?), color: userStatusTint(u['status'] as String?)),
                          if (auth.isDuperAdmin && u['appRole'] != 'duperadmin')
                            DropdownButton<String>(
                              value: assignableAppRoleValue(u['appRole'] as String?),
                              underline: const SizedBox.shrink(),
                              items: const [
                                DropdownMenuItem(value: 'user', child: Text('User')),
                                DropdownMenuItem(value: 'superadmin', child: Text('SuperAdmin')),
                              ],
                              onChanged: (v) {
                                if (v != null) _run(() => _setAppRole(u, v));
                              },
                            )
                          else
                            IosBadge(appRoleLabel(u['appRole'] as String?), color: iosPurple),
                          if (u['id'] != auth.id && u['appRole'] != 'duperadmin')
                            TextButton(
                              onPressed: () => _run(() => context.read<Api>().delete('/api/users/${u['id']}')),
                              child: const Text('Delete', style: TextStyle(color: iosRed)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
