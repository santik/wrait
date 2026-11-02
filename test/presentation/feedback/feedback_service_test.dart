import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_doubles/l10n_test_helper.dart';

import 'package:wrait/presentation/feedback/feedback_model.dart';
import 'package:wrait/presentation/feedback/feedback_preparation_sheet.dart';
import 'package:wrait/presentation/feedback/feedback_service.dart';
import 'package:wrait/presentation/theme/design_tokens.dart';

void main() {
  testWidgets('returns submitted after the fake Wiredash flow succeeds', (
    tester,
  ) async {
    FeedbackDraft? receivedDraft;
    final service = WiredashFeedbackService(
      isConfigured: true,
      launchFlow: ({required context, required draft, required appArea}) async {
        receivedDraft = draft;
        expect(appArea, 'main');
        return true;
      },
    );

    final result = await _openService(tester, service);

    expect(result.status, FeedbackLaunchStatus.submitted);
    expect(receivedDraft?.category, FeedbackCategory.idea);
    expect(receivedDraft?.replyContact, 'Signal: wrait-test');
    expect(receivedDraft?.message, 'The recording flow is clear.');
  });

  testWidgets('returns cancelled when the fake Wiredash flow is cancelled', (
    tester,
  ) async {
    final service = WiredashFeedbackService(
      isConfigured: true,
      launchFlow: ({required context, required draft, required appArea}) async {
        return false;
      },
    );

    final result = await _openService(tester, service);

    expect(result.status, FeedbackLaunchStatus.cancelled);
  });

  testWidgets('returns unavailable without Wiredash credentials', (
    tester,
  ) async {
    final service = WiredashFeedbackService(isConfigured: false);

    final result = await _openService(tester, service);

    expect(result.status, FeedbackLaunchStatus.unavailable);
  });

  testWidgets('returns unavailable when Wiredash is not mounted', (
    tester,
  ) async {
    final service = WiredashFeedbackService(isConfigured: true);

    final result = await _openService(tester, service);

    expect(result.status, FeedbackLaunchStatus.unavailable);
  });

  testWidgets('returns failed when the submission times out', (tester) async {
    final service = WiredashFeedbackService(
      isConfigured: true,
      launchFlow: ({required context, required draft, required appArea}) async {
        throw TimeoutException('feedback request timed out');
      },
    );

    final result = await _openService(tester, service);

    expect(result.status, FeedbackLaunchStatus.failed);
  });

  testWidgets('coalesces concurrent open calls into one feedback flow', (
    tester,
  ) async {
    late BuildContext pageContext;
    final completion = Completer<bool>();
    var launchCount = 0;
    final service = WiredashFeedbackService(
      isConfigured: true,
      launchFlow: ({required context, required draft, required appArea}) {
        launchCount += 1;
        return completion.future;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    final first = service.open(pageContext, appArea: 'main');
    final second = service.open(pageContext, appArea: 'main');
    expect(identical(first, second), isTrue);

    await tester.pumpAndSettle();
    expect(find.text('send feedback'), findsOneWidget);
    await tester.tap(find.text('Idea'));
    await tester.pump();
    await tester.enterText(
      find.byKey(feedbackMessageFieldKey),
      'The recording flow is clear.',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(feedbackSubmitButtonKey));
    await tester.tap(find.byKey(feedbackSubmitButtonKey));
    await tester.pump();
    expect(launchCount, 1);

    completion.complete(true);
    final results = await Future.wait([first, second]);
    expect(results[0].status, FeedbackLaunchStatus.submitted);
    expect(results[1].status, FeedbackLaunchStatus.submitted);
  });

  testWidgets('preserves the draft after failure so retry can succeed', (
    tester,
  ) async {
    var attempts = 0;
    final service = WiredashFeedbackService(
      isConfigured: true,
      launchFlow: ({required context, required draft, required appArea}) async {
        attempts += 1;
        if (attempts == 1) {
          throw StateError('network failure');
        }
        return true;
      },
    );

    final firstResult = await _openService(tester, service);
    expect(firstResult.status, FeedbackLaunchStatus.failed);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Idea'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(feedbackContactFieldKey))
          .controller!
          .text,
      'Signal: wrait-test',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(feedbackMessageFieldKey))
          .controller!
          .text,
      'The recording flow is clear.',
    );
    await tester.ensureVisible(find.byKey(feedbackSubmitButtonKey));
    await tester.tap(find.byKey(feedbackSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(attempts, 2);
  });

  testWidgets('keeps the preparation panel anchored while the keyboard opens', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);

    FeedbackLaunchResult? result;
    final service = WiredashFeedbackService(isConfigured: false);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await service.open(context, appArea: 'main');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final panelBeforeKeyboard = tester.getRect(
      find.byKey(feedbackPreparationPanelKey),
    );
    final buttonBottomSpaceBeforeKeyboard =
        panelBeforeKeyboard.bottom -
        tester.getRect(find.byKey(feedbackSubmitButtonKey)).bottom;
    expect(
      buttonBottomSpaceBeforeKeyboard,
      closeTo(WraitSpacingTokens.xs, 0.1),
    );
    final titleTopBeforeKeyboard = tester
        .getRect(find.text('send feedback'))
        .top;

    final contactField = find.byKey(feedbackContactFieldKey);
    final contactFieldElement = tester.element(contactField);
    await tester.tap(contactField);
    final contactFocusNode = tester
        .widget<TextField>(find.byKey(feedbackContactFieldKey))
        .focusNode!;
    expect(contactFocusNode.hasFocus, isTrue);

    tester.view.physicalSize = const Size(400, 480);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pump(const Duration(milliseconds: 200));

    expect(contactFocusNode.hasFocus, isTrue);
    expect(tester.element(contactField), same(contactFieldElement));

    expect(
      tester.getRect(find.text('send feedback')).top,
      closeTo(titleTopBeforeKeyboard, 0.1),
    );
    expect(
      tester.getRect(find.byKey(feedbackPreparationPanelKey)),
      panelBeforeKeyboard,
    );
    expect(
      panelBeforeKeyboard.bottom -
          tester.getRect(find.byKey(feedbackSubmitButtonKey)).bottom,
      closeTo(buttonBottomSpaceBeforeKeyboard, 0.1),
    );
    await tester.ensureVisible(find.byKey(feedbackSubmitButtonKey));
    expect(
      tester.getRect(find.byKey(feedbackSubmitButtonKey)).bottom,
      lessThanOrEqualTo(480),
    );

    tester.view.physicalSize = const Size(400, 800);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();
    expect(result?.status, FeedbackLaunchStatus.cancelled);
  });

  testWidgets('keeps the full form visible when the keyboard fits below it', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);

    FeedbackLaunchResult? result;
    final service = WiredashFeedbackService(isConfigured: false);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await service.open(context, appArea: 'main');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final panelBeforeKeyboard = tester.getRect(
      find.byKey(feedbackPreparationPanelKey),
    );
    final titleTopBeforeKeyboard = tester
        .getRect(find.text('send feedback'))
        .top;
    final submitBottomBeforeKeyboard = tester
        .getRect(find.byKey(feedbackSubmitButtonKey))
        .bottom;

    final messageField = find.byKey(feedbackMessageFieldKey);
    await tester.tap(messageField);
    final messageFocusNode = tester.widget<TextField>(messageField).focusNode!;
    expect(messageFocusNode.hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pump(const Duration(milliseconds: 200));

    expect(messageFocusNode.hasFocus, isTrue);
    expect(
      tester.getRect(find.byKey(feedbackPreparationPanelKey)),
      panelBeforeKeyboard,
    );
    expect(
      tester.getRect(find.text('send feedback')).top,
      closeTo(titleTopBeforeKeyboard, 0.1),
    );
    expect(
      tester.getRect(find.byKey(feedbackSubmitButtonKey)).bottom,
      closeTo(submitBottomBeforeKeyboard, 0.1),
    );
    expect(
      tester.getRect(find.byKey(feedbackPreparationPanelKey)).bottom,
      lessThanOrEqualTo(680),
    );

    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();
    expect(result?.status, FeedbackLaunchStatus.cancelled);
  });
}

Future<FeedbackLaunchResult> _openService(
  WidgetTester tester,
  FeedbackService service,
) async {
  FeedbackLaunchResult? result;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async {
              result = await service.open(context, appArea: 'main');
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Idea'));
  await tester.enterText(
    find.byKey(feedbackContactFieldKey),
    'Signal: wrait-test',
  );
  await tester.enterText(
    find.byKey(feedbackMessageFieldKey),
    'The recording flow is clear.',
  );
  await tester.pump();
  await tester.ensureVisible(find.byKey(feedbackSubmitButtonKey));
  await tester.tap(find.byKey(feedbackSubmitButtonKey));
  await tester.pumpAndSettle();

  return result!;
}
