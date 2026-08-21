import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth_state.dart';
import '../paths.dart';
import '../widgets.dart';

class CpNewUserScreen extends StatefulWidget {
  const CpNewUserScreen({super.key});

  @override
  State<CpNewUserScreen> createState() => _CpNewUserScreenState();
}

class _CpNewUserScreenState extends State<CpNewUserScreen> {
  final username = TextEditingController();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool makeSuperAdmin = false;
  String? error;
  bool busy = false;

  @override
  void dispose() {
    username.dispose();
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final u = username.text.trim();
    final n = name.text.trim();
    final e = email.text.trim();
    if (u.isEmpty || n.isEmpty || e.isEmpty || password.text.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await context.read<Api>().post('/api/users', {
        'username': u,
        'name': n,
        'email': e,
        'password': password.text,
        if (makeSuperAdmin) 'appRole': 'superadmin',
      });
      if (!mounted) return;
      context.go(cpUsers);
    } catch (err) {
      setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 88,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.go(cpUsers),
          child: const Text('Cancel'),
        ),
        title: const Text('New User'),
      ),
      body: ContentWidth(
        maxWidth: 520,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Creates an approved account. The user must change their password on first sign-in.',
                style: TextStyle(fontSize: 15, color: Color(0xFF8E8E93), height: 1.35),
              ),
            ),
            if (error != null) IosErrorBanner(error!),
            InsetGroup(
              header: 'Account',
              children: [
                TextField(controller: username, decoration: iosInput('Username'), autocorrect: false),
                TextField(controller: name, decoration: iosInput('Name')),
                TextField(
                  controller: email,
                  decoration: iosInput('Email'),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                ),
                TextField(controller: password, decoration: iosInput('Temporary password'), obscureText: true),
              ],
            ),
            if (auth.isDuperAdmin)
              InsetGroup(
                header: 'Application role',
                footer: 'SuperAdmins can manage workspaces and the user master.',
                children: [
                  SwitchListTile(
                    title: const Text('SuperAdmin'),
                    value: makeSuperAdmin,
                    onChanged: (v) => setState(() => makeSuperAdmin = v),
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
