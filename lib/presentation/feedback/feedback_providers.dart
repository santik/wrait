import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import 'feedback_service.dart';

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  final appConfig = ref.watch(appConfigProvider);
  return WiredashFeedbackService(
    isConfigured: appConfig.wiredashConfigured,
    projectId: appConfig.wiredashProjectId,
    secret: appConfig.wiredashSecret,
    environment: appConfig.wiredashEnvironment,
  );
});
