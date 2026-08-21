import 'package:flutter_test/flutter_test.dart';

import 'package:case2case/main.dart';

void main() {
  testWidgets('app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const Case2CaseApp());
    expect(find.byType(Case2CaseApp), findsOneWidget);
  });
}
