import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/presentation/main/button_area.dart';
import 'package:wrait/presentation/main/pulse_ring.dart';
import 'package:wrait/presentation/main/recording_state.dart';
import 'package:wrait/presentation/theme/design_tokens.dart';
import 'package:wrait/presentation/theme/wrait_theme.dart';

void main() {
  testWidgets('renders the adaptive button diameter across widths', (
    tester,
  ) async {
    await _pumpButtonArea(tester, width: 200);
    expect(
      tester.getSize(find.byKey(const ValueKey('actionButton'))).width,
      160,
    );

    await _pumpButtonArea(tester, width: 393);
    expect(
      tester.getSize(find.byKey(const ValueKey('actionButton'))).width,
      closeTo(220.08, 0.01),
    );

    await _pumpButtonArea(tester, width: 900);
    expect(
      tester.getSize(find.byKey(const ValueKey('actionButton'))).width,
      280,
    );
  });

  testWidgets('shows wrait or stop labels based on listening state', (
    tester,
  ) async {
    await _pumpButtonArea(tester);
    expect(find.text('wrait'), findsOneWidget);

    await _pumpButtonArea(
      tester,
      recordingState: RecordingListening(
        hardCapDeadlineElapsedRealtime: 120000,
      ),
      buttonLabel: 'stop',
      countdownProgress: 1,
    );
    expect(find.text('stop'), findsOneWidget);
  });

  testWidgets('uses reduced opacity during uploading and processing', (
    tester,
  ) async {
    await _pumpButtonArea(tester, recordingState: const RecordingUploading());
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      WraitButtonTokens.alphaDisabled,
    );

    await _pumpButtonArea(tester, recordingState: const RecordingProcessing());
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      WraitButtonTokens.alphaDisabled,
    );
  });

  testWidgets('shows pulse and countdown only while listening', (tester) async {
    await _pumpButtonArea(tester);
    expect(find.byKey(const ValueKey('pulseRing')), findsNothing);
    expect(find.byKey(const ValueKey('countdownRing')), findsNothing);

    await _pumpButtonArea(
      tester,
      recordingState: RecordingListening(
        hardCapDeadlineElapsedRealtime: 120000,
      ),
      buttonLabel: 'stop',
      countdownProgress: 0.5,
    );
    expect(find.byKey(const ValueKey('pulseRing')), findsOneWidget);
    expect(find.byKey(const ValueKey('countdownRing')), findsOneWidget);
  });

  testWidgets(
    'uses the provided viewport pulse diameter without resizing the button',
    (tester) async {
      await _pumpButtonArea(
        tester,
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
        buttonLabel: 'stop',
        countdownProgress: 0.5,
        pulseDiameter: 700,
      );

      final pulseRing = tester.widget<PulseRing>(
        find.byKey(const ValueKey('pulseRing')),
      );

      expect(pulseRing.endDiameter, 700);
      expect(pulseRing.startDiameter, closeTo(220.08, 0.01));
      expect(
        tester.getSize(find.byKey(const ValueKey('actionButton'))).width,
        closeTo(220.08, 0.01),
      );
    },
  );

  testWidgets('falls back to the minimum pulse diameter for missing inputs', (
    tester,
  ) async {
    await _pumpButtonArea(
      tester,
      recordingState: RecordingListening(
        hardCapDeadlineElapsedRealtime: 120000,
      ),
      buttonLabel: 'stop',
      countdownProgress: 0.5,
    );

    final pulseRing = tester.widget<PulseRing>(
      find.byKey(const ValueKey('pulseRing')),
    );

    expect(
      pulseRing.endDiameter,
      closeTo(pulseRing.startDiameter * WraitButtonTokens.pulseScaleMax, 0.01),
    );
  });

  testWidgets('rejects undersized and invalid pulse diameters', (tester) async {
    await _pumpButtonArea(
      tester,
      recordingState: RecordingListening(
        hardCapDeadlineElapsedRealtime: 120000,
      ),
      buttonLabel: 'stop',
      countdownProgress: 0.5,
      pulseDiameter: 100,
    );

    var pulseRing = tester.widget<PulseRing>(
      find.byKey(const ValueKey('pulseRing')),
    );
    expect(
      pulseRing.endDiameter,
      closeTo(pulseRing.startDiameter * WraitButtonTokens.pulseScaleMax, 0.01),
    );

    await _pumpButtonArea(
      tester,
      recordingState: RecordingListening(
        hardCapDeadlineElapsedRealtime: 120000,
      ),
      buttonLabel: 'stop',
      countdownProgress: 0.5,
      pulseDiameter: double.nan,
    );

    pulseRing = tester.widget<PulseRing>(
      find.byKey(const ValueKey('pulseRing')),
    );
    expect(
      pulseRing.endDiameter,
      closeTo(pulseRing.startDiameter * WraitButtonTokens.pulseScaleMax, 0.01),
    );
  });

  testWidgets('clamps oversized pulse diameters to the supported maximum', (
    tester,
  ) async {
    await _pumpButtonArea(
      tester,
      recordingState: RecordingListening(
        hardCapDeadlineElapsedRealtime: 120000,
      ),
      buttonLabel: 'stop',
      countdownProgress: 0.5,
      pulseDiameter: 5000,
    );

    final pulseRing = tester.widget<PulseRing>(
      find.byKey(const ValueKey('pulseRing')),
    );

    expect(pulseRing.endDiameter, WraitButtonTokens.pulseDiameterMax);
  });

  testWidgets('restarts the shake animation when the shake key changes', (
    tester,
  ) async {
    await _pumpButtonArea(
      tester,
      recordingState: const RecordingErrorState(RecordingError.tooShort),
      shakeErrorKey: 0,
    );
    final initialCenter = tester.getCenter(
      find.byKey(const ValueKey('actionButton')),
    );

    await _pumpButtonArea(
      tester,
      recordingState: const RecordingErrorState(RecordingError.tooShort),
      shakeErrorKey: 1,
    );
    await tester.pump(const Duration(milliseconds: 40));

    final shakenCenter = tester.getCenter(
      find.byKey(const ValueKey('actionButton')),
    );
    expect(shakenCenter.dx, isNot(initialCenter.dx));
  });

  testWidgets('exposes listening countdown semantics while active', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      await _pumpButtonArea(
        tester,
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
        buttonLabel: 'stop',
        countdownProgress: 0.5,
      );

      final semantics = tester
          .getSemantics(find.byKey(const ValueKey('actionButton')))
          .getSemanticsData();

      expect(
        semantics.label,
        contains(
          'Recording action button. Listening with countdown indicator.',
        ),
      );
      expect(semantics.value, 'stop');
      expect(semantics.hint, 'Double tap to stop recording.');
    } finally {
      semanticsHandle.dispose();
    }
  });
}

Future<void> _pumpButtonArea(
  WidgetTester tester, {
  double width = 393,
  RecordingState recordingState = const RecordingIdle(),
  int shakeErrorKey = 0,
  String buttonLabel = 'wrait',
  double? countdownProgress,
  double? pulseDiameter,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: wraitLightTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: ButtonArea(
              recordingState: recordingState,
              shakeErrorKey: shakeErrorKey,
              buttonLabel: buttonLabel,
              countdownProgress: countdownProgress,
              pulseDiameter: pulseDiameter,
              onPressed: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
