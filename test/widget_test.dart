// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:njbibleapp/app_state.dart';
import 'package:njbibleapp/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding renders welcome headline', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final appState = AppState(subscribeToAuthChanges: false);
    await appState.load();
    await tester.pumpWidget(BibleApp(appState: appState));

    expect(find.text('Get started'), findsOneWidget);
    expect(find.textContaining('Your word is a lamp'), findsWidgets);
  });
}
