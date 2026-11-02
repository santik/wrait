import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_doubles/l10n_test_helper.dart';

import 'package:wrait/presentation/feedback/feedback_model.dart';
import 'package:wrait/presentation/feedback/feedback_preparation_sheet.dart';

void main() {
  testWidgets(
    'collects a category, arbitrary contact text, and privacy acknowledgement',
    (tester) async {
      FeedbackDraft? result;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await showFeedbackPreparationDialog(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Bug'), findsOneWidget);
      expect(find.text('Idea'), findsOneWidget);
      expect(find.text('Confusing'), findsOneWidget);
      expect(find.text('Praise'), findsOneWidget);
      expect(find.text('continue'), findsNothing);
      expect(find.text('submit'), findsOneWidget);
      expect(find.byKey(feedbackMessageFieldKey), findsOneWidget);
      expect(
        tester.getRect(find.byKey(feedbackMessageFieldKey)).top,
        greaterThan(tester.getRect(find.byKey(feedbackContactFieldKey)).bottom),
      );
      expect(find.byKey(feedbackPrivacyCopyKey), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(feedbackSubmitButtonKey))
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Bug'));
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Bug'))
            .selected,
        isTrue,
      );
      await tester.enterText(
        find.byKey(feedbackContactFieldKey),
        'not-an-email',
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(feedbackSubmitButtonKey))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byKey(feedbackMessageFieldKey), '  \n  ');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(feedbackSubmitButtonKey))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(feedbackMessageFieldKey),
        'The recording flow is clear.',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(feedbackMessageFieldKey))
            .controller!
            .text,
        'The recording flow is clear.',
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(feedbackSubmitButtonKey))
            .onPressed,
        isNotNull,
      );
      await tester.ensureVisible(find.byKey(feedbackSubmitButtonKey));
      await tester.tap(find.byKey(feedbackSubmitButtonKey));
      await tester.pumpAndSettle();

      expect(result?.category, FeedbackCategory.bug);
      expect(result?.replyContact, 'not-an-email');
      expect(result?.message, 'The recording flow is clear.');
    },
  );

  testWidgets('limits feedback text to 2,048 characters', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(body: FeedbackPreparationSheet()),
      ),
    );

    final messageField = find.byKey(feedbackMessageFieldKey);
    expect(tester.widget<TextField>(messageField).maxLength, 2048);
    expect(tester.widget<TextField>(messageField).maxLines, 10);

    await tester.enterText(messageField, 'x' * 2050);
    await tester.pump();

    expect(
      tester.widget<TextField>(messageField).controller!.text.length,
      2048,
    );
  });

  testWidgets('exposes meaningful semantics for all feedback controls', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(body: FeedbackPreparationSheet()),
      ),
    );

    final bugSemantics = tester.getSemantics(
      find.widgetWithText(ChoiceChip, 'Bug'),
    );
    expect(bugSemantics.label, contains('Bug'));
    expect(bugSemantics.flagsCollection.isButton, isTrue);

    expect(find.bySemanticsLabel('reply contact (optional)'), findsOneWidget);
    expect(find.bySemanticsLabel('feedback'), findsOneWidget);

    expect(tester.getSemantics(find.text('cancel')).label, 'cancel');
    expect(
      tester.getSemantics(find.byKey(feedbackSubmitButtonKey)).label,
      contains('submit'),
    );
    semanticsHandle.dispose();
  });

  testWidgets('cancel closes without returning a draft', (tester) async {
    FeedbackDraft? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showFeedbackPreparationDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byKey(feedbackPrivacyCopyKey), findsNothing);
  });
}
