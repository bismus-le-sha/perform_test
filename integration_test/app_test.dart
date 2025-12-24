import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:perform_test/presentation/profile/widgets/photo_list_item.dart';
import 'package:perform_test/presentation/skeleton/skeleton.dart';
import 'test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App integration tests', () {
    late Widget app;

    setUpAll(() async {
      app = await createTestApp();
    });

    // testWidgets('App starts and shows photo feed', (tester) async {
    //   await tester.pumpWidget(app);

    //   expect(find.byType(SkeletonPlaceholder), findsOneWidget);
    //   await tester.pumpAndSettle(const Duration(seconds: 3));

    //   expect(find.byType(PhotoListItem), findsWidgets);
    //   await waitForImagesToLoad(tester);
    // });

    // testWidgets('Scrolls photo feed and loads more photos', (tester) async {
    //   await tester.pumpWidget(app);
    //   await tester.pumpAndSettle(const Duration(seconds: 2));

    //   final scrollable = find.byType(Scrollable).first;
    //   await tester.drag(scrollable, const Offset(0, -2200));
    //   await tester.pumpAndSettle();

    //   await waitForImagesToLoad(tester);
    //   expect(find.byType(PhotoListItem), findsWidgets);
    // });

    // testWidgets('Switches between bottom navigation tabs', (tester) async {
    //   await tester.pumpWidget(app);
    //   await tester.pumpAndSettle(const Duration(seconds: 2));

    //   final bottomNavigation = find.byType(BottomNavigationBar);
    //   expect(bottomNavigation, findsOneWidget);

    //   // Tab 2 — Likes
    //   await tester.tap(find.text('Likes'));
    //   await tester.pumpAndSettle();
    //   expect(find.text('Just an empty dummy tab'), findsOneWidget);

    //   // Tab 3 — Performance
    //   await tester.tap(find.text('Performance'));
    //   await tester.pump();
    //   expect(find.text('KILL UI THREAD ☠️'), findsOneWidget);
    // });

    // testWidgets('Performs calculation in Performance tab', (tester) async {
    //   await tester.pumpWidget(app);
    //   await tester.pumpAndSettle(const Duration(seconds: 2));

    //   final bottomNavigation = find.byType(BottomNavigationBar);
    //   expect(bottomNavigation, findsOneWidget);

    //   // Переходим на вкладку Performance
    //   await tester.tap(find.text('Performance'));
    //   await tester.pump(); // первый фрейм

    //   // Ожидаем появления кнопки
    //   final killButton = find.text('KILL UI THREAD ☠️');
    //   await tester.tap(killButton);

    //   // Ждём завершения расчёта
    //   final result = find.textContaining('Result:');
    //   await waitForFinder(tester, result);
    // });

    testWidgets('Full user flow from feed to performance tab', (tester) async {
      // Загружаем тестовое окружение
      await tester.pumpWidget(app);

      // Первый кадр — отображается skeleton
      expect(find.byType(SkeletonPlaceholder), findsOneWidget);

      // Ждём завершения FutureBuilder
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Проверяем, что фото лента загрузилась
      expect(find.byType(PhotoListItem), findsWidgets);
      await waitForImagesToLoad(tester);

      // Прокрутка списка вниз на 1200 пикселей
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -2200));
      await tester.pumpAndSettle();

      await waitForImagesToLoad(tester);
      // Проверяем, что прокрутка прошла успешно
      // (можно проверять, что последний элемент виден или сдвинут)
      expect(find.byType(PhotoListItem), findsWidgets);

      // Переход на второй таб (DummyTab)
      final bottomNavigation = find.byType(BottomNavigationBar);
      expect(bottomNavigation, findsOneWidget);

      // Tab 2 — Likes
      await tester.tap(find.text('Likes'));
      await tester.pumpAndSettle();
      expect(find.text('Just an empty dummy tab'), findsOneWidget);

      // Tab 3 — Performance
      await tester.tap(find.text('Performance'));
      await tester.pump();
      final killButton = find.text('KILL UI THREAD ☠️');
      expect(killButton, findsOneWidget);

      // Ожидаем появления кнопки
      await tester.tap(killButton);

      // Ждём завершения расчёта
      final result = find.textContaining('Result:');
      await waitForFinder(tester, result);
    });
  });
}

Future<void> waitForImagesToLoad(WidgetTester tester) async {
  bool allImagesLoaded() {
    final imageWidgets = tester.widgetList<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    if (imageWidgets.isEmpty) return false;
    return imageWidgets.every((w) => w.opacity == 1);
  }

  // Ждём, пока все картинки станут полностью видимыми
  await tester.runAsync(() async {
    await tester.pump(const Duration(milliseconds: 100));
    for (int i = 0; i < 50; i++) {
      if (allImagesLoaded()) break;
      await tester.pump(const Duration(milliseconds: 200));
    }
  });
}

Future<void> waitForFinder(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final endTime = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(endTime)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw Exception('Timeout waiting for ${finder.describeMatch(Plurality.one)}');
}
