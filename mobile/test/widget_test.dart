import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acservice_mobile/core/constants/app_constants.dart';
import 'package:acservice_mobile/main.dart';

void main() {
  testWidgets('App navigates to clean LoginScreen without demo logins or server URL UI', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: CaringCoolTechApp(),
      ),
    );

    expect(find.byType(CaringCoolTechApp), findsOneWidget);

    // Advance past 2.6s splash delay + 600ms page transition
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Caring Cool Tech Operations'), findsOneWidget);
    expect(find.text('Sign In to Workspace'), findsOneWidget);

    // Verify demo login UI, pre-filled demo credentials, and server URL switcher are removed
    expect(find.text('Show Demo Credentials'), findsNothing);
    expect(find.text('admin@frostpro.in'), findsNothing);
    expect(find.text('Demo@1234'), findsNothing);
    expect(find.text('Server: ${AppConstants.productionApiUrl}'), findsNothing);
    expect(find.text('Server Backend URL'), findsNothing);
  });
}
