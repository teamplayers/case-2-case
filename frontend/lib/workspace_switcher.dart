import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'auth_state.dart';
import 'paths.dart';
import 'theme.dart';
import 'workspace_store.dart';

class WorkspaceSwitcher extends StatelessWidget {
  const WorkspaceSwitcher({super.key, this.currentWorkspaceId});

  final String? currentWorkspaceId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final auth = context.watch<AuthState>();
    final workspaces = store.workspaces;
    final current = currentWorkspaceId != null ? store.byId(currentWorkspaceId!) : null;
    final label = current?['name'] as String? ?? (workspaces.isEmpty ? 'Workspace' : 'Switch workspace');

    return PopupMenuButton<String>(
      tooltip: 'Switch workspace',
      onSelected: (value) {
        if (value == '__cp__') {
          context.go(cpWorkspaces);
          return;
        }
        if (value == '__pick__') {
          context.go('/wspace');
          return;
        }
        switchWorkspace(context, value);
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];
        if (auth.isAppOperator) {
          items.add(
            const PopupMenuItem(
              value: '__cp__',
              child: Row(
                children: [
                  Icon(CupertinoIcons.gear_alt, size: 18, color: iosPurple),
                  SizedBox(width: 10),
                  Text('Control panel'),
                ],
              ),
            ),
          );
          items.add(const PopupMenuDivider());
        }
        if (workspaces.isEmpty) {
          items.add(
            const PopupMenuItem(
              enabled: false,
              child: Text('No workspaces', style: TextStyle(color: iosSecondary)),
            ),
          );
        } else {
          for (final w in workspaces) {
            final id = w['id'] as String;
            final selected = id == currentWorkspaceId;
            items.add(
              PopupMenuItem(
                value: id,
                child: Row(
                  children: [
                    if (selected) const Icon(CupertinoIcons.checkmark, size: 16, color: iosBlue) else const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(w['name'] as String? ?? 'Workspace', overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            );
          }
        }
        if (workspaces.length > 1) {
          items.add(const PopupMenuDivider());
          items.add(const PopupMenuItem(value: '__pick__', child: Text('All workspaces…')));
        }
        return items;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: iosBlue),
              ),
            ),
            const Icon(CupertinoIcons.chevron_down, size: 13, color: iosBlue),
          ],
        ),
      ),
    );
  }
}

List<Widget> topBarActions(BuildContext context, {String? workspaceId}) {
  return [WorkspaceSwitcher(currentWorkspaceId: workspaceId)];
}
