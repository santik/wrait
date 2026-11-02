import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:wiredash/wiredash.dart';

import 'feedback_model.dart';

Map<String, Object> buildFeedbackMetadata({
  required FeedbackDraft draft,
  required String appArea,
  required Locale locale,
  required TargetPlatform platform,
}) {
  final metadata = <String, Object>{
    'app_area': appArea,
    'platform': _platformName(platform),
    'locale': locale.toLanguageTag(),
    'feedback_category': _categoryValue(draft.category),
  };

  if (draft.replyContact.trim().isNotEmpty) {
    metadata['reply_contact'] = draft.replyContact.trim();
  }

  return Map<String, Object>.unmodifiable(metadata);
}

CustomizableWiredashMetaData applyFeedbackMetadata({
  required CustomizableWiredashMetaData metadata,
  required FeedbackDraft draft,
  required String appArea,
  required Locale locale,
  required TargetPlatform platform,
}) {
  final safeMetadata = buildFeedbackMetadata(
    draft: draft,
    appArea: appArea,
    locale: locale,
    platform: platform,
  );
  final replyContact = safeMetadata['reply_contact'];

  final explicitContact = replyContact is String ? replyContact : null;

  // Wiredash's userEmail field is server-validated even when its prompt is
  // hidden. Keep the reply contact as free text in the non-email userId field
  // and the allowlisted custom field instead.
  metadata.userEmail = null;
  metadata.userId = explicitContact;
  metadata.custom = safeMetadata;
  return metadata;
}

// Stable, non-localized value. Capitalized to match the historical English
// labels ('Bug', 'Idea', ...) so existing Wiredash dashboard filters keep working.
String _categoryValue(FeedbackCategory category) =>
    category.name[0].toUpperCase() + category.name.substring(1);

String _platformName(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  _ => 'unsupported',
};
