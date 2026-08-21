import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../paths.dart';
import '../widgets.dart';
import '../workspace_store.dart';

class WorkspaceIndex extends StatefulWidget {
  const WorkspaceIndex({super.key});

  @override
  State<WorkspaceIndex> createState() => _WorkspaceIndexState();
}

class _WorkspaceIndexState extends State<WorkspaceIndex> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<WorkspaceStore>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    if (store.loading && store.workspaces.isEmpty) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator(radius: 12)));
    }
    return SafeArea(
      child: ContentWidth(
        maxWidth: 860,
        child: ListView(
          children: [
            LargeTitle(
              'Workspaces',
              subtitle: 'Create and manage workspaces.',
              actions: [
                AddAction(onPressed: () => context.go(cpWorkspaceNew)),
              ],
            ),
            if (store.error != null) IosErrorBanner(store.error!),
            if (store.workspaces.isEmpty)
              const IosEmpty(
                icon: CupertinoIcons.square_grid_2x2,
                title: 'No workspaces',
                message: 'Tap Add to create the first one.',
              )
            else
              InsetGroup(
                header: 'All workspaces',
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
