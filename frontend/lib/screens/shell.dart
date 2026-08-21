import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth_state.dart';
import '../paths.dart';
import '../roles.dart';
import '../theme.dart';
import '../workspace_store.dart';
import '../workspace_switcher.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.workspaceId, required this.child});

  final String workspaceId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final ws = context.watch<WorkspaceStore>().byId(workspaceId);
    final loc = GoRouterState.of(context).uri.path;
    final canUsers = canManageWorkspaceMembers(ws, auth.id, appRole: auth.appRole);
    final canSettings = canManageWorkspaceSettings(ws, auth.id, appRole: auth.appRole);
    final items = <_Nav>[
      _Nav('Cases', CupertinoIcons.tray_full, wspaceCases(workspaceId)),
      if (canUsers) _Nav('Users', CupertinoIcons.person_2, wspaceUsers(workspaceId)),
      if (canSettings) _Nav('Settings', CupertinoIcons.gear, wspaceSettings(workspaceId)),
      _Nav('You', CupertinoIcons.person_crop_circle, wspaceYou(workspaceId)),
    ];
    var index = items.indexWhere((n) => loc == n.path || (n.path.endsWith('/cases') && loc.contains('/cases')));
    if (index < 0) index = 0;
    if (loc.contains('/users')) index = items.indexWhere((n) => n.path.endsWith('/users'));
    if (loc.contains('/settings')) index = items.indexWhere((n) => n.path.endsWith('/settings'));
    if (loc.endsWith('/you')) index = items.indexWhere((n) => n.path.endsWith('/you'));
    if (index < 0) index = 0;

    final wide = MediaQuery.sizeOf(context).width >= 860;
    final roleLabel = auth.isAppOperator
        ? appRoleLabel(auth.appRole)
        : workspaceRoleLabel(workspaceRole(ws, auth.id) ?? 'member');
    final wsName = ws?['name'] as String? ?? 'Workspace';

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 268,
              color: const Color(0xFFF7F7F8),
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 8, 8, 12),
                    child: Text('case2case', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    child: Text(wsName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  for (var i = 0; i < items.length; i++)
                    _SideItem(
                      label: items[i].label,
                      icon: items[i].icon,
                      selected: i == index,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.go(items[i].path);
                      },
                    ),
                  if (auth.isAppOperator) ...[
                    const SizedBox(height: 12),
                    _SideItem(
                      label: 'Control panel',
                      icon: CupertinoIcons.gear_alt,
                      selected: false,
                      onTap: () => context.go(cpWorkspaces),
                    ),
                  ],
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: Text('${auth.username}  ·  $roleLabel', style: const TextStyle(fontSize: 13, color: iosSecondary)),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 0.5, thickness: 0.5),
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: topBarActions(context, workspaceId: workspaceId),
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(wsName, overflow: TextOverflow.ellipsis),
        actions: topBarActions(context, workspaceId: workspaceId),
      ),
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF0F9F9F9),
          border: Border(top: BorderSide(color: iosSeparator.withValues(alpha: 0.55), width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            context.go(items[i].path);
          },
          destinations: [
            for (final item in items)
              NavigationDestination(icon: Icon(item.icon), selectedIcon: Icon(item.icon, color: iosBlue), label: item.label),
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? iosBlue.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? iosBlue : iosSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? iosBlue : iosLabel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Nav {
  const _Nav(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}
