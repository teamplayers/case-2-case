import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth_state.dart';
import '../widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final username = TextEditingController();
  final name = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  String? error;
  String? success;
  bool busy = false;

  @override
  void dispose() {
    username.dispose();
    name.dispose();
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      busy = true;
      error = null;
      success = null;
    });
    try {
      final result = await context.read<AuthState>().register(
            username: username.text.trim(),
            name: name.text.trim(),
            email: email.text.trim(),
            password: pass.text,
          );
      setState(() => success = result['message'] as String? ?? 'Account pending approval.');
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
          onPressed: () => context.go('/login'),
          child: const Text('Cancel'),
        ),
        title: const Text('Create Account'),
      ),
      body: ContentWidth(
        maxWidth: 420,
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 40),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'Sign up joins the user master list. A SuperAdmin must approve your account before you can sign in.',
                style: TextStyle(fontSize: 15, color: Color(0xFF8E8E93), height: 1.35),
              ),
            ),
            if (error != null) IosErrorBanner(error!),
            if (success != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(success!, style: const TextStyle(color: Color(0xFF34C759), fontSize: 15)),
              ),
            InsetGroup(
              header: 'User master',
              children: [
                TextField(controller: username, decoration: iosInput('Username'), autocorrect: false),
                TextField(controller: name, decoration: iosInput('Name')),
                TextField(controller: email, decoration: iosInput('Email'), keyboardType: TextInputType.emailAddress, autocorrect: false),
                TextField(controller: pass, decoration: iosInput('Password'), obscureText: true),
              ],
            ),
            IosPrimaryButton(label: busy ? 'Submitting…' : 'Sign up', onPressed: busy ? null : _submit),
            if (success != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: IosPrimaryButton(label: 'Back to sign in', onPressed: () => context.go('/login')),
              ),
          ],
        ),
      ),
    );
  }
}
