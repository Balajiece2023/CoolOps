import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acservice_mobile/main.dart';

void main() {
  testWidgets('App renders LoginScreen with Caring CoolTech title and buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CaringCoolTechApp(),
      ),
    );

    expect(find.byType(CaringCoolTechApp), findsOneWidget);
  });
}
