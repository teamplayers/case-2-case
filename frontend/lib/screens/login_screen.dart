import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth_state.dart';
import '../theme.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final user = TextEditingController(text: 'admin');
  final pass = TextEditingController(text: 'admin');
  String? error;
  bool busy = false;

  @override
  void dispose() {
    user.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await context.read<AuthState>().login(user.text.trim(), pass.text);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 420,
          child: ListView(
            padding: const EdgeInsets.only(top: 48, bottom: 40),
            children: [
              const LargeTitle('Sign In', subtitle: 'case2case  ·  the case desk'),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Text(
                  'First-time DuperAdmin is duperadmin / duperadmin — you will be asked to change it. New sign-ups need SuperAdmin approval.',
                  style: TextStyle(fontSize: 15, color: iosSecondary, height: 1.35),
                ),
              ),
              if (error != null) IosErrorBanner(error!),
              InsetGroup(
                header: 'Credentials',
                children: [
                  TextField(
                    controller: user,
                    decoration: iosInput('Username'),
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                  ),
                  TextField(
                    controller: pass,
                    decoration: iosInput('Password'),
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ),
              IosPrimaryButton(label: busy ? 'Signing in…' : 'Sign In', onPressed: busy ? null : _submit),
              Center(
                child: CupertinoButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Create an account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
