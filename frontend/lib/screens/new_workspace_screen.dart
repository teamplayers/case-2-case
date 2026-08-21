import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../paths.dart';
import '../widgets.dart';
import '../workspace_store.dart';

class NewWorkspaceScreen extends StatefulWidget {
  const NewWorkspaceScreen({super.key});

  @override
  State<NewWorkspaceScreen> createState() => _NewWorkspaceScreenState();
}

class _NewWorkspaceScreenState extends State<NewWorkspaceScreen> {
  final name = TextEditingController();
  final description = TextEditingController();
  String? error;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (name.text.trim().isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final created = await context.read<WorkspaceStore>().create(
            name: name.text.trim(),
            description: description.text.trim(),
          );
      if (!mounted) return;
      context.go(wspaceCases(created['id'] as String));
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ContentWidth(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          children: [
            LargeTitle(
              'New workspace',
              actions: [
                TextButton(onPressed: () => context.go(cpWorkspaces), child: const Text('Cancel')),
              ],
            ),
            if (error != null) IosErrorBanner(error!),
            InsetGroup(
              header: 'Workspace',
              children: [
                TextField(controller: name, decoration: iosInput('Name'), textInputAction: TextInputAction.next),
                TextField(controller: description, decoration: iosInput('Description (optional)'), maxLines: 3),
              ],
            ),
            IosPrimaryButton(label: busy ? 'Creating…' : 'Create Workspace', onPressed: busy ? null : _submit),
          ],
        ),
      ),
    );
  }
}
