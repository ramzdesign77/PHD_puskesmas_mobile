import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:klinik_sanitasi_mobile/models/education_article.dart';
import 'package:klinik_sanitasi_mobile/services/api_service.dart';
import 'package:klinik_sanitasi_mobile/theme/app_theme.dart';
import 'package:klinik_sanitasi_mobile/views/public/home_view.dart';

void main() {
  testWidgets('education articles paginate with responsive numbered controls', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeView(
          apiService: _PaginatedArticlesApiService(),
          greetingName: 'Warga',
          onOpenReports: () {},
          onOpenTracking: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.ensureVisible(find.text('Artikel Edukasi'));
    await tester.pumpAndSettle();

    expect(find.text('Artikel 01'), findsOneWidget);
    expect(find.text('Artikel 02'), findsOneWidget);
    expect(find.text('Artikel 03'), findsOneWidget);
    expect(find.text('Artikel 04'), findsNothing);
    expect(find.byKey(const Key('education_page_0')), findsOneWidget);
    expect(find.byKey(const Key('education_page_1')), findsOneWidget);
    expect(find.byKey(const Key('education_page_2')), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('education_previous_page')))
          .onPressed,
      isNull,
    );

    final firstPageAreaHeight = tester
        .getSize(find.byKey(const Key('education_article_page_area_0')))
        .height;
    await tester.tap(find.byKey(const Key('education_page_2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Artikel 01'), findsNothing);
    expect(find.text('Artikel 07'), findsOneWidget);
    expect(find.text('Artikel 09'), findsOneWidget);
    expect(find.text('Artikel 10'), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const Key('education_article_page_area_2')))
          .height,
      firstPageAreaHeight,
    );
    expect(find.text('…'), findsNWidgets(2));
    final selectedPageButton = tester.widget<TextButton>(
      find.byKey(const Key('education_page_2')),
    );
    expect(
      selectedPageButton.style?.backgroundColor?.resolve({}),
      const Color(0xFF0284C7),
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('education_previous_page')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);

    final nextPage = find.byKey(const Key('education_next_page'));
    for (var page = 3; page < 5; page++) {
      await tester.ensureVisible(nextPage);
      await tester.tap(nextPage);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
    }

    expect(find.text('Artikel 13'), findsOneWidget);
    expect(find.text('Artikel 14'), findsOneWidget);
    expect(find.text('Artikel 12'), findsNothing);
    expect(tester.widget<IconButton>(nextPage).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}

class _PaginatedArticlesApiService extends ApiService {
  @override
  Future<List<EducationArticle>> getArticles() async => [
    for (var index = 1; index <= 14; index++)
      EducationArticle(
        id: index,
        title: 'Artikel ${index.toString().padLeft(2, '0')}',
        category: 'Edukasi',
        excerpt: 'Ringkasan artikel $index',
        content: 'Konten artikel $index',
      ),
  ];
}
