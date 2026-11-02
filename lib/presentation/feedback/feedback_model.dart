import '../../l10n/app_localizations.dart';

enum FeedbackCategory { bug, idea, confusing, praise }

extension FeedbackCategoryLabel on FeedbackCategory {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    FeedbackCategory.bug => l10n.feedbackCategoryBug,
    FeedbackCategory.idea => l10n.feedbackCategoryIdea,
    FeedbackCategory.confusing => l10n.feedbackCategoryConfusing,
    FeedbackCategory.praise => l10n.feedbackCategoryPraise,
  };
}

class FeedbackDraft {
  const FeedbackDraft({
    required this.category,
    required this.replyContact,
    required this.message,
  });

  final FeedbackCategory category;
  final String replyContact;
  final String message;
}
