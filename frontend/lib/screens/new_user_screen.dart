import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../paths.dart';
import '../widgets.dart';
import '../workspace_store.dart';

class NewUserScreen extends StatefulWidget {
  const NewUserScreen({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  State<NewUserScreen> createState() => _NewUserScreenState();
}

class _NewUserScreenState extends State<NewUserScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  String role = 'agent';
  String? error;
  bool busy = false;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (username.text.trim().isEmpty || password.text.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    final api = context.read<Api>();
    final store = context.read<WorkspaceStore>();
    try {
      final created = await api.post('/api/users', {
        'username': username.text.trim(),
        'password': password.text,
        'role': role,
      }) as Map;
      final ws = store.byId(widget.workspaceId);
      final members = {...List<String>.from(ws?['memberIds'] ?? []), created['id'] as String};
      await store.save(widget.workspaceId, {'memberIds': members.toList()});
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
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 88,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.go(wspaceUsers(widget.workspaceId)),
          child: const Text('Cancel'),
        ),
        title: const Text('New User'),
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          children: [
            if (error != null) IosErrorBanner(error!),
            InsetGroup(
              header: 'Login',
              footer: 'They will be added to this workspace.',
              children: [
                TextField(controller: username, decoration: iosInput('Username'), autocorrect: false),
                TextField(controller: password, decoration: iosInput('Temporary password'), obscureText: true),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: DropdownButtonFormField(
                    key: ValueKey(role),
                    initialValue: role,
                    decoration: iosInput('Role'),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'agent', child: Text('Agent')),
                      DropdownMenuItem(value: 'customer', child: Text('Customer')),
                    ],
                    onChanged: (v) => setState(() => role = v as String),
                  ),
                ),
              ],
            ),
            IosPrimaryButton(label: busy ? 'Creating…' : 'Create User', onPressed: busy ? null : _submit),
          ],
        ),
      ),
    );
  }
}
