import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth_state.dart';
import '../paths.dart';
import '../widgets.dart';
import '../workspace_store.dart';
import '../workspace_switcher.dart';

class WorkspacePickerScreen extends StatelessWidget {
  const WorkspacePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final auth = context.watch<AuthState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspaces'),
        actions: topBarActions(context),
      ),
      body: ContentWidth(
        child: ListView(
          children: [
            LargeTitle(
              'Workspaces',
              subtitle: 'Pick a space to work in.',
              actions: [
                if (auth.isAppOperator) AddAction(onPressed: () => context.go(cpWorkspaces), label: 'Control panel'),
              ],
            ),
            if (store.loading)
              const LoadingBody()
            else if (store.workspaces.isEmpty)
              IosEmpty(
                icon: CupertinoIcons.square_grid_2x2,
                title: 'No workspaces',
                message: auth.isAppOperator
                    ? 'Create one in the control panel.'
                    : 'A workspace admin must add you to a workspace.',
              )
            else
              InsetGroup(
                header: 'Your workspaces',
                children: [
                  for (final w in store.workspaces)
                    IosCell(
                      title: w['name'] as String? ?? 'Workspace',
                      subtitle: w['description'] as String?,
                      chevron: true,
                      onTap: () => context.go(wspaceCases(w['id'] as String)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
