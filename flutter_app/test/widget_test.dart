import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_app/app.dart';

void main() {
  testWidgets('FitCity boots to splash scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitCityApp()));
    await tester.pumpAndSettle();

    expect(find.text('Splash'), findsOneWidget);
  });
}
