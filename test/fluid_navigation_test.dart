import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klinik_sanitasi_mobile/views/main_layout_screen.dart';
import 'package:klinik_sanitasi_mobile/widgets/fluid_bottom_nav.dart';

void main() {
  testWidgets('labeled navigation floats its selection over a smooth notch', (
    tester,
  ) async {
    var selectedIndex = 0;
    const destinations = [
      FluidNavDestination(label: 'Beranda', icon: Icons.home_outlined),
      FluidNavDestination(label: 'Profil', icon: Icons.person_outline_rounded),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => FluidBottomNav(
              destinations: destinations,
              selectedIndex: selectedIndex,
              showLabels: true,
              onDestinationSelected: (index) {
                setState(() => selectedIndex = index);
              },
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(FluidBottomNav)).height, 82);
    expect(find.text('Beranda'), findsOneWidget);
    final selectedBubble = tester.widget<Container>(
      find.byKey(const Key('fluid_nav_drop_Beranda')),
    );
    expect(
      (selectedBubble.decoration! as BoxDecoration).shape,
      BoxShape.circle,
    );
    expect(
      tester.getSize(find.byKey(const Key('fluid_nav_drop_Beranda'))).width,
      38,
    );
    final navClip = tester.widget<ClipPath>(
      find.byKey(const Key('fluid_nav_clip')),
    );
    final navRect = tester.getRect(find.byKey(const Key('fluid_nav_clip')));
    final notchPath = navClip.clipper!.getClip(navRect.size);
    final bubbleCenter =
        tester.getCenter(find.byKey(const Key('fluid_nav_drop_Beranda'))) -
        navRect.topLeft;
    expect(notchPath.contains(bubbleCenter), isFalse);
    expect(notchPath.contains(bubbleCenter.translate(0, 26)), isTrue);
    expect(find.byKey(const Key('fluid_nav_active_backdrop')), findsNothing);

    await tester.tap(find.text('Profil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byKey(const Key('fluid_nav_drop_Profil')), findsOneWidget);
    expect(find.byKey(const Key('fluid_nav_drop_Beranda')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('floating fluid navigation changes pages on a narrow screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    var selectedIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => MainLayoutScreen(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              setState(() => selectedIndex = index);
            },
            pages: const [
              Center(child: Text('Halaman Beranda')),
              Center(child: Text('Halaman Laporan')),
              Center(child: Text('Halaman IKL')),
              Center(child: Text('Halaman Profil')),
            ],
            destinations: const [
              FluidNavDestination(
                label: 'Beranda',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
              ),
              FluidNavDestination(
                label: 'Laporan',
                icon: Icons.fact_check_outlined,
              ),
              FluidNavDestination(
                label: 'Input IKL',
                icon: Icons.note_add_outlined,
              ),
              FluidNavDestination(
                label: 'Profil',
                icon: Icons.person_outline_rounded,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Halaman Beranda'), findsOneWidget);
    expect(find.byType(FluidBottomNav), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBody, isFalse);
    expect(tester.getSize(find.byType(FluidBottomNav)).height, 64);
    final navSurface = tester.widget<DecoratedBox>(
      find.byKey(const Key('fluid_nav_surface')),
    );
    expect((navSurface.decoration as BoxDecoration).color, Colors.white);
    expect(find.byType(BackdropFilter), findsNothing);
    final selectedDrop = tester.widget<Container>(
      find.byKey(const Key('fluid_nav_drop_Beranda')),
    );
    expect((selectedDrop.decoration! as BoxDecoration).shape, BoxShape.circle);
    expect(
      tester.getSize(find.byKey(const Key('fluid_nav_drop_Beranda'))).width,
      36,
    );
    expect(tester.widget<Icon>(find.byIcon(Icons.home_rounded)).size, 22);
    expect(find.text('Beranda'), findsNothing);
    final navRect = tester.getRect(find.byType(FluidBottomNav));
    final clip = tester.widget<ClipPath>(
      find.byKey(const Key('fluid_nav_clip')),
    );
    expect(clip.clipBehavior, Clip.antiAlias);
    final notchPath = clip.clipper!.getClip(navRect.size);
    final buttonCenter =
        tester.getCenter(find.byIcon(Icons.home_rounded)) - navRect.topLeft;
    expect(notchPath.contains(buttonCenter), isFalse);
    expect(notchPath.contains(buttonCenter.translate(0, 22)), isFalse);
    expect(notchPath.contains(buttonCenter.translate(0, 25)), isTrue);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Halaman Profil'), findsOneWidget);
    expect(find.byKey(const Key('fluid_nav_drop_Profil')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
