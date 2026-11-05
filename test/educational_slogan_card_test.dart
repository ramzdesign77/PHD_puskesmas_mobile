import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/wave.dart';

import 'package:klinik_sanitasi_mobile/widgets/educational_slogan_card.dart';

void main() {
  testWidgets('slogan card clips animated waves behind a dark overlay', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 320, child: EducationalSloganCard()),
          ),
        ),
      ),
    );

    final card = tester.widget<Container>(
      find.byKey(const Key('education_slogan_card')),
    );
    expect(card.clipBehavior, Clip.antiAlias);
    expect(
      (card.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(24),
    );

    final wave = tester.widget<WaveWidget>(find.byType(WaveWidget));
    expect(wave.config, isA<CustomConfig>());
    expect(
      find.byKey(const Key('education_slogan_card_overlay')),
      findsOneWidget,
    );

    final slogan = tester.widget<Text>(
      find.text('Lingkungan Bersih, Sumber Air Sehat, Keluarga Kuat'),
    );
    expect(slogan.textAlign, TextAlign.center);
    expect(slogan.style?.color, Colors.white);
    expect(slogan.style?.fontFamily, 'Poppins');
    expect(slogan.style?.fontSize, 15);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slogan card supports a custom slogan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EducationalSloganCard(slogan: 'Jaga air, jaga kesehatan.'),
        ),
      ),
    );

    expect(find.text('Jaga air, jaga kesehatan.'), findsOneWidget);
  });
}
