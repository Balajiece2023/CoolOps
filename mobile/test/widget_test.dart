import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acservice_mobile/main.dart';
import 'package:acservice_mobile/presentation/screens/login_screen.dart';

void main() {
  testWidgets('App renders LoginScreen with FrostPro title and buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FrostProApp(),
      ),
    );

    expect(find.text('FrostPro AC Operations'), findsOneWidget);
    expect(find.text('Sign In to Workspace'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Technician'), findsOneWidget);
  });
}
