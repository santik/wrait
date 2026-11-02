import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import 'feedback_model.dart';
import 'feedback_preparation_sheet.dart';
import 'wiredash_feedback_submission.dart';

enum FeedbackLaunchStatus { submitted, cancelled, unavailable, failed }

class FeedbackLaunchResult {
  const FeedbackLaunchResult(this.status);

  final FeedbackLaunchStatus status;
}

typedef WiredashFlowLauncher = Future<bool> Function({
  required BuildContext context,
  required FeedbackDraft draft,
  required String appArea,
});

abstract interface class FeedbackService {
  Future<FeedbackLaunchResult> open(
    BuildContext context, {
    required String appArea,
  });
}

class WiredashFeedbackService implements FeedbackService {
  WiredashFeedbackService({
    required this.isConfigured,
    this.projectId = '',
    this.secret = '',
    this.environment = 'dev',
    this.launchFlow,
    this.submission,
  });

  final bool isConfigured;
  final String projectId;
  final String secret;
  final String environment;
  final WiredashFlowLauncher? launchFlow;
  final WiredashFeedbackSubmission? submission;
  FeedbackDraft? _pendingDraft;
  Future<FeedbackLaunchResult>? _openInFlight;

  @override
  Future<FeedbackLaunchResult> open(
    BuildContext context, {
    required String appArea,
  }) {
    final existingRequest = _openInFlight;
    if (existingRequest != null) {
      return existingRequest;
    }

    late final Future<FeedbackLaunchResult> request;
    request = _openInternal(context, appArea: appArea).whenComplete(() {
      if (identical(_openInFlight, request)) {
        _openInFlight = null;
      }
    });
    _openInFlight = request;
    return request;
  }

  Future<FeedbackLaunchResult> _openInternal(
    BuildContext context, {
    required String appArea,
  }) async {
    final draft = await showFeedbackPreparationDialog(
      context,
      initialDraft: _pendingDraft,
    );

    if (draft == null) {
      _pendingDraft = null;
      return const FeedbackLaunchResult(FeedbackLaunchStatus.cancelled);
    }

    if (!context.mounted) {
      return const FeedbackLaunchResult(FeedbackLaunchStatus.cancelled);
    }

    _pendingDraft = draft;
    if (!isConfigured ||
        (launchFlow == null &&
            (submission == null &&
                (projectId.trim().isEmpty || secret.trim().isEmpty)))) {
      return const FeedbackLaunchResult(FeedbackLaunchStatus.unavailable);
    }

    try {
      final submitted = launchFlow != null
          ? await launchFlow!(context: context, draft: draft, appArea: appArea)
          : await (submission ??
                    WiredashFeedbackSubmission(
                      projectId: projectId,
                      secret: secret,
                      environment: environment,
                    ))
                .submit(context: context, draft: draft, appArea: appArea);

      if (submitted) {
        _pendingDraft = null;
        developer.log(
          'Feedback submission succeeded.',
          name: 'FeedbackService',
        );
        return const FeedbackLaunchResult(FeedbackLaunchStatus.submitted);
      }

      _pendingDraft = null;
      return const FeedbackLaunchResult(FeedbackLaunchStatus.cancelled);
    } catch (error, stackTrace) {
      developer.log(
        'Feedback submission failed.',
        name: 'FeedbackService',
        error: error,
        stackTrace: stackTrace,
      );
      return const FeedbackLaunchResult(FeedbackLaunchStatus.failed);
    }
  }
}
