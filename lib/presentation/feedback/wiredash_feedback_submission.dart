// ignore_for_file: depend_on_referenced_packages, implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:wiredash/src/core/services/services.dart' show WiredashServices;
import 'package:wiredash/src/feedback/data/feedback_submitter.dart'
    show SubmissionState;
import 'package:wiredash/src/metadata/session_meta_data.dart'
    show SessionMetaData;
import 'package:wiredash/wiredash.dart';

import 'feedback_metadata.dart';
import 'feedback_model.dart';

typedef FeedbackSubmissionOverride = Future<bool> Function({
  required BuildContext context,
  required FeedbackDraft draft,
  required String appArea,
});

class WiredashFeedbackSubmission {
  const WiredashFeedbackSubmission({
    required this.projectId,
    required this.secret,
    required this.environment,
    this.override,
  });

  final String projectId;
  final String secret;
  final String environment;
  final FeedbackSubmissionOverride? override;

  Future<bool> submit({
    required BuildContext context,
    required FeedbackDraft draft,
    required String appArea,
  }) {
    final submissionOverride = override;
    if (submissionOverride != null) {
      return submissionOverride(
        context: context,
        draft: draft,
        appArea: appArea,
      );
    }

    return _submitWithWiredash(
      context: context,
      draft: draft,
      appArea: appArea,
    );
  }

  Future<bool> _submitWithWiredash({
    required BuildContext context,
    required FeedbackDraft draft,
    required String appArea,
  }) async {
    final locale = Localizations.localeOf(context);
    final platform = defaultTargetPlatform;
    final feedbackOptions = WiredashFeedbackOptions(
      labels: const [],
      email: EmailPrompt.hidden,
      screenshot: ScreenshotPrompt.hidden,
      collectMetaData: (metadata) {
        return applyFeedbackMetadata(
          metadata: metadata,
          draft: draft,
          appArea: appArea,
          locale: locale,
          platform: platform,
        );
      },
    );

    final services = WiredashServices();
    try {
      services.updateWidget(
        Wiredash(
          projectId: projectId,
          secret: secret,
          environment: environment,
          feedbackOptions: feedbackOptions,
          child: const SizedBox.shrink(),
        ),
      );
      services.wiredashModel.sessionMetaData = SessionMetaData(
        appLocale: locale,
        appBrightness: Theme.of(context).brightness,
      );

      final feedbackModel = services.feedbackModel;
      feedbackModel.feedbackMessage = draft.message;
      final feedbackItem = await feedbackModel.createFeedback();
      final submission = await services.feedbackSubmitter.submit(feedbackItem);

      return submission == SubmissionState.submitted ||
          submission == SubmissionState.pending;
    } finally {
      services.dispose();
    }
  }
}
