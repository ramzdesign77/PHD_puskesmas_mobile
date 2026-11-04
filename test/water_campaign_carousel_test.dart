import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/wave.dart';

import 'package:klinik_sanitasi_mobile/models/education_article.dart';
import 'package:klinik_sanitasi_mobile/services/api_service.dart';
import 'package:klinik_sanitasi_mobile/theme/app_theme.dart';
import 'package:klinik_sanitasi_mobile/views/public/home_view.dart';

void main() {
  testWidgets('home hero has clipped, continuously animated cyan waves', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeView(
          apiService: _CampaignApiService(),
          greetingName: 'Warga',
          onOpenReports: () {},
          onOpenTracking: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    final wave = tester.widget<WaveWidget>(find.byType(WaveWidget));
    final config = wave.config as CustomConfig;
    expect(config.colors, const [
      Color(0x3306B6D4),
      Color(0x4D06B6D4),
      Color(0x6606B6D4),
    ]);
    expect(config.durations, const [12000, 9000, 7000]);
    expect(config.heightPercentages, const [0.42, 0.54, 0.66]);
    expect(wave.waveAmplitude, 24);
    expect(wave.isLoop, isTrue);
    expect(
      tester
          .widget<ClipRRect>(find.byKey(const Key('home_hero_wave_clip')))
          .borderRadius,
      BorderRadius.circular(28),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('campaign carousel swipes and changes pages in place', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigatorObserver = _RecordingNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        navigatorObservers: [navigatorObserver],
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
    final pageView = find.byKey(const Key('campaign_carousel_page_view'));
    await tester.ensureVisible(pageView);
    await tester.pump(const Duration(milliseconds: 450));
    navigatorObserver.reset();

    expect(find.text('Kampanye Sanitasi'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Kampanye Sanitasi')).style?.fontSize,
      18,
    );
    expect(
      tester.widget<Text>(find.text('Kampanye Sanitasi')).style?.fontWeight,
      FontWeight.w500,
    );
    expect(find.text('Stop Buang Air Besar Sembarangan'), findsOneWidget);
    final firstPillarTitle = tester.widget<Text>(
      find.text('Stop Buang Air Besar Sembarangan'),
    );
    expect(firstPillarTitle.style?.fontFamily, 'Poppins');
    expect(firstPillarTitle.style?.fontSize, 20);
    expect(firstPillarTitle.style?.fontWeight, FontWeight.w700);
    expect(tester.takeException(), isNull);

    await tester.drag(pageView, const Offset(-240, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Cuci Tangan Pakai Sabun'), findsOneWidget);
    expect(_indicatorWidth(tester, 1), 22);
    expect(_indicatorWidth(tester, 0), 7);
    expect(navigatorObserver.pushCount, 0);
    expect(tester.takeException(), isNull);

    final lastPageIndicator = find.byKey(
      const Key('campaign_page_indicator_4'),
    );
    await tester.ensureVisible(lastPageIndicator);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.tap(lastPageIndicator);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Pengamanan Limbah Cair Rumah Tangga'), findsOneWidget);
    expect(_indicatorWidth(tester, 4), 22);
    expect(navigatorObserver.pushCount, 0);
    expect(tester.takeException(), isNull);
  });
}

double _indicatorWidth(WidgetTester tester, int index) {
  final finder = find.descendant(
    of: find.byKey(Key('campaign_page_indicator_$index')),
    matching: find.byType(AnimatedContainer),
  );
  return tester.getSize(finder).width;
}

class _CampaignApiService extends ApiService {
  @override
  Future<List<EducationArticle>> getArticles() async => [];
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  void reset() => pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }
}
