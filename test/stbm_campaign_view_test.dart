import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klinik_sanitasi_mobile/models/education_article.dart';
import 'package:klinik_sanitasi_mobile/services/api_service.dart';
import 'package:klinik_sanitasi_mobile/theme/app_theme.dart';
import 'package:klinik_sanitasi_mobile/views/public/home_view.dart';

void main() {
  testWidgets(
    'campaign banner opens the five STBM pillars on a narrow screen',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomeView(
            apiService: _CampaignApiService(),
            greetingName: 'Warga',
            onOpenReports: () {},
            onOpenTracking: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Kampanye Sanitasi'), findsOneWidget);
      expect(find.text('5 Pilar STBM'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Kampanye Sanitasi')).style?.fontWeight,
        FontWeight.w500,
      );
      final homeError = tester.takeException();
      expect(homeError, isNull, reason: '$homeError');

      await tester.ensureVisible(find.text('Pelajari selengkapnya'));
      await tester.tap(find.text('Pelajari selengkapnya'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Stop Buang Air Besar Sembarangan'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Pengamanan Limbah Cair Rumah Tangga'),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Pengamanan Limbah Cair Rumah Tangga'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _CampaignApiService extends ApiService {
  @override
  Future<List<EducationArticle>> getArticles() async => [];
}
