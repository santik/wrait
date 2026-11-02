// ignore_for_file: depend_on_referenced_packages, implementation_imports

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_doubles/l10n_test_helper.dart';

import 'package:wiredash/src/core/options/environment_detector.dart'
    show EnvironmentDetector;
import 'package:wiredash/src/core/network/wiredash_api.dart'
    show BaseClient, BaseRequest, Request, StreamedResponse, WiredashApi;
import 'package:wiredash/src/core/services/services.dart' show WiredashServices;
import 'package:wiredash/src/core/wiredash_model.dart' show WiredashModel;
import 'package:wiredash/src/core/wuid_generator.dart' show WuidGenerator;
import 'package:wiredash/src/feedback/data/direct_feedback_submitter.dart'
    show DirectFeedbackSubmitter;
import 'package:wiredash/src/feedback/data/feedback_submitter.dart'
    show FeedbackItem, FeedbackSubmitter, SubmissionState;
import 'package:wiredash/src/feedback/feedback_model.dart' show FeedbackModel;
import 'package:wiredash/src/metadata/all_meta_data.dart'
    show WiredashWindowPadding;
import 'package:wiredash/src/metadata/build_info/app_info.dart' show AppInfo;
import 'package:wiredash/src/metadata/build_info/build_info.dart'
    show BuildInfo, CompilationMode;
import 'package:wiredash/src/metadata/device_info/device_info.dart'
    show FlutterInfo;
import 'package:wiredash/src/metadata/meta_data_collector.dart'
    show DeviceInfo, FixedMetaData, MetaDataCollector;
import 'package:wiredash/src/utils/disposable.dart' show Disposable;
import 'package:wiredash/wiredash.dart';
import 'package:wrait/presentation/feedback/feedback_model.dart';
import 'package:wrait/presentation/feedback/wiredash_feedback_submission.dart';

void main() {
  testWidgets('submits the complete draft through the injected boundary', (
    tester,
  ) async {
    FeedbackDraft? receivedDraft;
    var receivedAppArea = '';
    final submission = WiredashFeedbackSubmission(
      projectId: 'project-id',
      secret: 'secret',
      environment: 'dev',
      override: ({required context, required draft, required appArea}) async {
        receivedDraft = draft;
        receivedAppArea = appArea;
        return true;
      },
    );

    late BuildContext pageContext;
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

    final submitted = await submission.submit(
      context: pageContext,
      draft: const FeedbackDraft(
        category: FeedbackCategory.idea,
        replyContact: 'Signal: wrait-test',
        message: 'The recording flow is clear.',
      ),
      appArea: 'main',
    );

    expect(submitted, isTrue);
    expect(receivedAppArea, 'main');
    expect(receivedDraft?.category, FeedbackCategory.idea);
    expect(receivedDraft?.replyContact, 'Signal: wrait-test');
    expect(receivedDraft?.message, 'The recording flow is clear.');
  });

  testWidgets('builds a direct provider item without opening provider UI', (
    tester,
  ) async {
    late _RecordingSubmitter submitter;
    WiredashFeedbackOptions? capturedOptions;
    var wiredashWasActive = true;

    WiredashServices.debugServicesCreator = () => _createAdapterTestServices(
      feedbackSubmitterFactory: (services) {
        submitter = _RecordingSubmitter(
          onSubmit: () {
            capturedOptions = services.wiredashModel.feedbackOptions;
            wiredashWasActive = services.wiredashModel.isWiredashActive;
          },
        );
        return submitter;
      },
    );
    addTearDown(() => WiredashServices.debugServicesCreator = null);

    late BuildContext pageContext;
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

    final submitted =
        await WiredashFeedbackSubmission(
          projectId: 'project-id',
          secret: 'secret',
          environment: 'dev',
        ).submit(
          context: pageContext,
          draft: const FeedbackDraft(
            category: FeedbackCategory.idea,
            replyContact: '  Signal: wrait-test  ',
            message: '  The recording flow is clear.  ',
          ),
          appArea: 'main',
        );

    expect(submitted, isTrue);
    expect(submitter.item?.message, 'The recording flow is clear.');
    expect(submitter.item?.attachments, isEmpty);
    expect(submitter.item?.labels, isEmpty);
    expect(submitter.item?.metadata.userId, 'Signal: wrait-test');
    expect(submitter.item?.metadata.userEmail, isNull);
    final expectedPlatform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'unsupported',
    };
    expect(submitter.item?.metadata.custom, {
      'app_area': 'main',
      'platform': expectedPlatform,
      'locale': 'en',
      'feedback_category': 'Idea',
      'reply_contact': 'Signal: wrait-test',
    });
    expect(capturedOptions?.labels, isEmpty);
    expect(capturedOptions?.email, EmailPrompt.hidden);
    expect(capturedOptions?.screenshot, ScreenshotPrompt.hidden);
    expect(wiredashWasActive, isFalse);
  });

  testWidgets('uses the pinned SDK transport without provider network access', (
    tester,
  ) async {
    final client = _RecordingHttpClient();
    WiredashServices.debugServicesCreator = () => _createAdapterTestServices(
      api: WiredashApi(
        httpClient: client,
        projectId: 'project-id',
        secret: 'secret',
      ),
      feedbackSubmitterFactory: (services) =>
          DirectFeedbackSubmitter(() => services.api),
    );
    addTearDown(() => WiredashServices.debugServicesCreator = null);

    late BuildContext pageContext;
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

    final submitted =
        await WiredashFeedbackSubmission(
          projectId: 'project-id',
          secret: 'secret',
          environment: 'dev',
        ).submit(
          context: pageContext,
          draft: const FeedbackDraft(
            category: FeedbackCategory.praise,
            replyContact: 'Signal: wrait-test',
            message: 'The recording flow is clear.',
          ),
          appArea: 'main',
        );

    expect(submitted, isTrue);
    final request = client.request;
    expect(request, isNotNull);
    expect(request!.method, 'POST');
    expect(request.url.toString(), 'https://api.wiredash.io/sdk/sendFeedback');
    expect(request.headers['project'], 'project-id');
    expect(request.headers['secret'], 'secret');
    // Wiredash encodes semantic version 2.6.1 as 261 in this header.
    expect(request.headers['version'], '261');

    final requestBody =
        jsonDecode((request as Request).body) as Map<String, dynamic>;
    expect(requestBody['message'], 'The recording flow is clear.');
    expect(requestBody['labels'], isEmpty);
    final metadata = requestBody['metadata'] as Map<String, dynamic>;
    expect(metadata['userId'], 'Signal: wrait-test');
    expect(metadata.containsKey('userEmail'), isFalse);
    expect(
      (metadata['custom'] as Map<String, dynamic>)['reply_contact'],
      'Signal: wrait-test',
    );
  });
}

WiredashServices _createAdapterTestServices({
  WiredashApi? api,
  required FeedbackSubmitter Function(WiredashServices services)
  feedbackSubmitterFactory,
}) {
  return WiredashServices.setup((services) {
    services.inject<WiredashServices>((_) => services);
    services.inject<Wiredash?>((_) => null);
    services.inject<WuidGenerator>((_) => _FakeWuidGenerator());

    final metadataCollector = _FakeMetaDataCollector();
    services.inject<MetaDataCollector>((_) => metadataCollector);
    services.inject<EnvironmentDetector>(
      (_) => EnvironmentDetector(
        wiredashWidget: () => services.wiredashWidget,
        metaDataCollector: () => services.metaDataCollector,
        buildInfoProvider: () =>
            const BuildInfo(compilationMode: CompilationMode.debug),
      ),
    );
    services.inject<WiredashModel>((_) => WiredashModel(services));
    services.inject<FeedbackModel>((_) => FeedbackModel(services));
    if (api != null) {
      services.inject<WiredashApi>((_) => api);
    }
    services.inject<FeedbackSubmitter>(
      (_) => feedbackSubmitterFactory(services),
    );
  });
}

class _RecordingHttpClient extends BaseClient {
  BaseRequest? request;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    this.request = request;
    return StreamedResponse(
      Stream<List<int>>.value(utf8.encode('{}')),
      200,
      request: request,
    );
  }
}

class _RecordingSubmitter implements FeedbackSubmitter {
  _RecordingSubmitter({this.onSubmit});

  final VoidCallback? onSubmit;
  FeedbackItem? item;

  @override
  Future<SubmissionState> submit(FeedbackItem item) async {
    this.item = item;
    onSubmit?.call();
    return SubmissionState.submitted;
  }
}

class _FakeWuidGenerator implements WuidGenerator {
  @override
  Disposable addOnKeyCreatedListener(void Function(String key) listener) {
    return Disposable(() {});
  }

  @override
  String generateId(int length) => 'a' * length;

  @override
  Future<String> generatePersistedId(String key, int length) async {
    return 'device-id-1234567890';
  }
}

class _FakeMetaDataCollector extends MetaDataCollector {
  _FakeMetaDataCollector()
    : super(
        deviceInfoCollector: () => throw UnimplementedError(),
        buildInfoProvider: () =>
            const BuildInfo(compilationMode: CompilationMode.debug),
      );

  @override
  Future<FixedMetaData> collectFixedMetaData() async {
    return const FixedMetaData(
      appInfo: AppInfo(),
      deviceInfo: DeviceInfo(),
      buildInfo: BuildInfo(compilationMode: CompilationMode.debug),
    );
  }

  @override
  FlutterInfo collectFlutterInfo() {
    const padding = WiredashWindowPadding(left: 0, top: 0, right: 0, bottom: 0);
    return const FlutterInfo(
      platformLocale: 'en-US',
      platformSupportedLocales: ['en-US'],
      viewPadding: padding,
      physicalSize: Size(1, 1),
      pixelRatio: 1,
      platformBrightness: Brightness.light,
      textScaleFactor: 1,
      viewInsets: padding,
      gestureInsets: padding,
    );
  }
}
