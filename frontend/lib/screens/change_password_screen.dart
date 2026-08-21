import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_state.dart';
import '../theme.dart';
import '../widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final current = TextEditingController();
  final next = TextEditingController();
  String? error;
  bool busy = false;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await context.read<AuthState>().changePassword(current.text, next.text);
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final must = context.watch<AuthState>().mustChange;
    final body = ContentWidth(
      maxWidth: 420,
      child: ListView(
        padding: EdgeInsets.only(top: must ? 48 : 16, bottom: 40),
        children: [
          if (must) const LargeTitle('Change Password'),
          if (must)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'You must set a new password before continuing.',
                style: TextStyle(fontSize: 15, color: iosSecondary, height: 1.35),
              ),
            ),
          if (error != null) IosErrorBanner(error!),
          InsetGroup(
            header: 'Password',
            children: [
              TextField(controller: current, decoration: iosInput('Current password'), obscureText: true),
              TextField(controller: next, decoration: iosInput('New password'), obscureText: true),
            ],
          ),
          IosPrimaryButton(label: busy ? 'Saving…' : 'Save Password', onPressed: busy ? null : _submit),
        ],
      ),
    );

    if (must) return Scaffold(body: SafeArea(child: body));

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 88,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        title: const Text('Change Password'),
      ),
      body: body,
    );
  }
}
