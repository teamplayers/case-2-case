import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth_state.dart';
import '../paths.dart';
import '../theme.dart';
import '../workspace_switcher.dart';

class CpShell extends StatelessWidget {
  const CpShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final loc = GoRouterState.of(context).uri.path;
    final items = <_CpNav>[
      _CpNav('Workspaces', CupertinoIcons.square_grid_2x2, cpWorkspaces),
      _CpNav('Users', CupertinoIcons.person_3, cpUsers),
    ];
    var index = items.indexWhere((n) => loc.startsWith(n.path));
    if (index < 0) index = 0;
    final wide = MediaQuery.sizeOf(context).width >= 860;

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
                    child: Text('Control Panel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Text('PLATFORM', style: TextStyle(fontSize: 12, color: iosSecondary, letterSpacing: 0.4)),
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
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: Text('${auth.username}  ·  ${auth.appRole ?? 'operator'}', style: const TextStyle(fontSize: 13, color: iosSecondary)),
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
                      children: topBarActions(context),
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
        title: const Text('Control Panel'),
        actions: topBarActions(context),
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

class _CpNav {
  const _CpNav(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}
