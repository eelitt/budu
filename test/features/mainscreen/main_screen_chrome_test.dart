import 'package:budu/features/auth/data/user_profile_repository.dart';
import 'package:budu/features/auth/providers/user_provider.dart';
import 'package:budu/features/mainscreen/widgets/main_screen_app_bar.dart';
import 'package:budu/features/mainscreen/widgets/main_screen_bottom_nav_bar.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _appBarHarness({required bool nextMonthBudgetExists}) {
  return ChangeNotifierProvider(
    create: (_) => UserProvider(
      profiles: UserProfileRepository(firestore: FakeFirebaseFirestore()),
    ),
    child: MaterialApp(
      home: Scaffold(
        appBar: MainScreenAppBar(
          userFirstName: 'Testi',
          nextMonthBudgetExists: nextMonthBudgetExists,
          onMenuSelected: (_) {},
        ),
        body: const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bottom nav shows the three main tabs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MainScreenBottomNavigationBar(
            selectedIndex: 0,
            onItemTapped: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Muokkaa budjettia'), findsOneWidget);
    expect(find.text('Seuranta'), findsOneWidget);
    expect(find.text('Historia'), findsOneWidget);
  });

  testWidgets('create budget menu item shows when next month missing',
      (tester) async {
    await tester.pumpWidget(_appBarHarness(nextMonthBudgetExists: false));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Luo uusi budjetti'), findsOneWidget);
  });

  testWidgets('create budget menu item hidden when next month exists',
      (tester) async {
    await tester.pumpWidget(_appBarHarness(nextMonthBudgetExists: true));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Luo uusi budjetti'), findsNothing);
    expect(find.text('Lisää tapahtuma'), findsOneWidget);
  });
}
