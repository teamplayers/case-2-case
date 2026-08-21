import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'auth_state.dart';
import 'router.dart';
import 'theme.dart';
import 'workspace_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(const Case2CaseApp());
}

class Case2CaseApp extends StatefulWidget {
  const Case2CaseApp({super.key});

  @override
  State<Case2CaseApp> createState() => _Case2CaseAppState();
}

class _Case2CaseAppState extends State<Case2CaseApp> {
  final api = Api();
  late final AuthState auth = AuthState(api);
  late final WorkspaceStore workspaces = WorkspaceStore(api);
  late final router = createRouter(auth, workspaces);

  @override
  void initState() {
    super.initState();
    auth.addListener(_onAuth);
    auth.restore().then((_) {
      if (auth.isLoggedIn) workspaces.load();
    });
  }

  void _onAuth() {
    if (auth.isLoggedIn) {
      workspaces.load();
    } else {
      workspaces.clear();
    }
  }

  @override
  void dispose() {
    auth.removeListener(_onAuth);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: auth,
      child: ChangeNotifierProvider.value(
        value: workspaces,
        child: Provider<Api>.value(
          value: api,
          child: MaterialApp.router(
            title: 'case2case',
            debugShowCheckedModeBanner: false,
            theme: appTheme(),
            routerConfig: router,
          ),
        ),
      ),
    );
  }
}
