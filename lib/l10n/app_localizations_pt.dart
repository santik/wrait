// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get bootstrapTitle => 'abrindo o wrait';

  @override
  String get bootstrapSubtitle => 'carregando seu diário local';

  @override
  String get bootstrapErrorTitle => 'não foi possível abrir o wrait';

  @override
  String get bootstrapErrorSubtitle => 'tente novamente';

  @override
  String get bootstrapRetryButton => 'tentar de novo';

  @override
  String get mainSettingsTooltip => 'Ajustes';

  @override
  String get mainFeedbackTooltip => 'Enviar feedback';

  @override
  String mainLanguageLabel(String displayName) {
    return 'Idioma: $displayName';
  }

  @override
  String get mainLanguageUnavailable => 'Idioma indisponível · tente novamente';

  @override
  String get mainFeedbackSent => 'feedback enviado';

  @override
  String get mainFeedbackUnavailable =>
      'o feedback não está disponível no momento';

  @override
  String get mainFeedbackFailed =>
      'não foi possível enviar o feedback. tente novamente';

  @override
  String mainLanguageSemanticsLabel(String displayName) {
    return 'Idioma de transcrição selecionado: $displayName. Abre os ajustes do idioma de transcrição.';
  }

  @override
  String get mainSettingsSemanticsLabel => 'Ajustes';

  @override
  String get mainFeedbackSemanticsLabel => 'Enviar feedback';

  @override
  String mainQuotaSemanticsLabel(int limit, int remaining) {
    return 'Cota de gravação: $limit no total e $remaining restantes.';
  }

  @override
  String mainQuotaText(int limit, int remaining) {
    return '$limit no total / $remaining restantes';
  }

  @override
  String get mainButtonStop => 'parar';

  @override
  String get mainButtonWrait => 'wrait';

  @override
  String get statusTapToWrite => 'toque no botão para escrever';

  @override
  String get statusWrait => 'wrait';

  @override
  String get statusListening => 'ouvindo...';

  @override
  String get statusProcessing => 'processando...';

  @override
  String get statusCleaningUp => 'organizando o texto...';

  @override
  String get statusSavedTapToRead => 'salvo, toque para ler';

  @override
  String get statusDeleted => 'excluído';

  @override
  String get statusNoConnectionDraft => 'sem conexão · salvo como rascunho';

  @override
  String get statusServiceUnavailableDraft =>
      'serviço indisponível · salvo como rascunho';

  @override
  String get statusServerConfigErrorDraft =>
      'erro de configuração do servidor · salvo como rascunho';

  @override
  String get statusSpeechNotRecognizedDraft =>
      'não reconhecido · salvo como rascunho';

  @override
  String get statusSpeechNotRecognized => 'não reconhecido';

  @override
  String get statusApiFailedDraft => 'salvo como rascunho · tentaremos de novo';

  @override
  String get statusTooShort => 'muito curto · continue falando';

  @override
  String get statusNothingCaught => 'nada captado · muito baixo?';

  @override
  String get statusMicNeeded => 'microfone necessário · toque de novo';

  @override
  String get statusMicBlocked => 'microfone bloqueado · toque em ajustes';

  @override
  String get statusNoConnection => 'sem conexão';

  @override
  String get statusServiceUnavailable => 'serviço indisponível';

  @override
  String get statusServerConfigError => 'erro de configuração do servidor';

  @override
  String get statusSomethingWentWrong => 'algo deu errado';

  @override
  String get statusMicNeededSemanticsLabel =>
      'O acesso ao microfone é necessário para iniciar a gravação.';

  @override
  String get statusMicNeededSemanticsHint =>
      'Toque duas vezes para solicitar o acesso ao microfone novamente.';

  @override
  String get statusMicBlockedSemanticsLabel =>
      'O acesso ao microfone está bloqueado para o wrait.';

  @override
  String get statusMicBlockedSemanticsHint =>
      'Toque duas vezes para abrir os ajustes do app.';

  @override
  String statusDefaultSemanticsLabel(String statusText) {
    return 'Mensagem de status: $statusText.';
  }

  @override
  String statsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas',
      one: '$count entrada',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '$count dia',
    );
    return '$_temp0';
  }

  @override
  String statsDisplay(String entries, String days) {
    return '$entries - $days';
  }

  @override
  String statsSemanticsLabel(String displayText) {
    return 'Estatísticas das entradas: $displayText. Abre a lista de entradas.';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsBack => 'Voltar';

  @override
  String get settingsPrivacy => 'Privacidade';

  @override
  String get settingsAppLock => 'Bloqueio do app';

  @override
  String get settingsAppLockDescription =>
      'Use o bloqueio de tela do seu dispositivo ao abrir ou voltar para o wrait.';

  @override
  String get settingsAppLockUnavailable =>
      'O bloqueio do app não está disponível nesta versão de validação.';

  @override
  String get settingsAppLockNoSecurity =>
      'Configure um bloqueio de tela no dispositivo antes de ativar o bloqueio do app.';

  @override
  String get settingsAppLockTemporarilyUnavailable =>
      'A autenticação do dispositivo está temporariamente indisponível. Tente novamente.';

  @override
  String get settingsAppLockUnavailableDevice =>
      'A autenticação do dispositivo não está disponível neste aparelho.';

  @override
  String get settingsAppLockSaveFailed =>
      'Não foi possível salvar a configuração do bloqueio do app. Tente novamente.';

  @override
  String get settingsAppLockSettingsFailed =>
      'Não foi possível abrir os ajustes de segurança do dispositivo.';

  @override
  String get settingsOpenDeviceSettings => 'Abrir ajustes do dispositivo';

  @override
  String get settingsAppearance => 'Aparência';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Escuro';

  @override
  String get settingsThemeSaveFailed =>
      'Não foi possível salvar o tema. Tente novamente.';

  @override
  String get settingsReminders => 'Lembretes';

  @override
  String get settingsRemindersToggle => 'Lembretes diários';

  @override
  String get settingsRemindersDescription =>
      'Receba lembretes para escrever no diário de manhã e à noite';

  @override
  String get settingsRemindersPermissionDenied =>
      'A permissão de notificações é necessária para os lembretes. Ative-a nas configurações do dispositivo.';

  @override
  String get reminderMorningTitle => 'wrait';

  @override
  String get reminderMorningBody => 'Comece o dia com uma reflexão';

  @override
  String get reminderEveningTitle => 'wrait';

  @override
  String get reminderEveningBody => 'Você ainda tem gravações restantes hoje';

  @override
  String get settingsTranscriptionLanguage => 'Idioma de transcrição';

  @override
  String get settingsTranscriptionLanguageDescription =>
      'Escolha o idioma em que você fala para melhorar a transcrição. A detecção automática é usada quando nenhum idioma está selecionado.';

  @override
  String get settingsAutomaticDetection => 'Detecção automática';

  @override
  String get settingsLoading => 'Carregando…';

  @override
  String get settingsTranscriptionLanguageLoadFailed =>
      'Não foi possível carregar o idioma de transcrição.';

  @override
  String get settingsTranscriptionLanguageSaveFailed =>
      'Não foi possível salvar o idioma. Tente novamente.';

  @override
  String get settingsTryAgain => 'Tentar de novo';

  @override
  String get settingsActivityMessage =>
      'Conclua a gravação ou a transcrição em andamento antes de alterar os ajustes.';

  @override
  String get entryListBack => 'Voltar';

  @override
  String get entryListBackSemanticsLabel => 'Voltar para a tela principal';

  @override
  String get entryListSearchLabel => 'Buscar entradas';

  @override
  String get entryListClearSearch => 'Limpar busca';

  @override
  String get entryListImportCsv => 'Importar CSV';

  @override
  String get entryListExportCsv => 'Exportar CSV';

  @override
  String get entryListImporting => 'Importando CSV';

  @override
  String get entryListExporting => 'Exportando CSV';

  @override
  String get entryListImportingSemanticsLabel => 'Importando entradas';

  @override
  String get entryListExportingSemanticsLabel => 'Exportando entradas';

  @override
  String get entryListImportSemanticsLabel => 'Importar entradas';

  @override
  String get entryListExportSemanticsLabel => 'Exportar entradas';

  @override
  String get entryListEmpty => 'nenhuma entrada ainda';

  @override
  String get entryListNoResults => 'Nenhuma entrada encontrada';

  @override
  String entryListExportSuccess(String fileName, String pathLabel) {
    return '$fileName exportado para $pathLabel.';
  }

  @override
  String get entryListExportFailed => 'Não foi possível exportar as entradas.';

  @override
  String entryListImportSuccess(int count, String fileName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'registros importados',
      one: 'registro importado',
    );
    return '$count $_temp0 de $fileName.';
  }

  @override
  String get entryListImportFailed => 'Não foi possível importar as entradas.';

  @override
  String get entryListImportInvalidFormat =>
      'O CSV selecionado não é uma exportação válida do wrait.';

  @override
  String get entryListImportUnreadableFile =>
      'Não foi possível ler o arquivo CSV selecionado.';

  @override
  String get entryListImportFileTooLarge =>
      'O CSV selecionado é grande demais para ser importado.';

  @override
  String get entryListImportStorageFailure =>
      'Não foi possível salvar as entradas importadas.';

  @override
  String get entryListAudioDraftPreview => 'pendente · tentaremos de novo';

  @override
  String get entryListAudioDraftStateDescription =>
      'Rascunho de áudio, ainda não transcrito';

  @override
  String get entryListDeleteActionLabel => 'Excluir entrada';

  @override
  String entryListRowSemanticsLabel(String timestamp, String languageLabel) {
    return 'Entrada de $timestamp. $languageLabel.';
  }

  @override
  String get entryListRowSwipeHint => 'Deslize para a direita para excluir.';

  @override
  String get entryListRowOpenHint =>
      'Toque duas vezes para abrir. Deslize para a direita para excluir.';

  @override
  String get entryListRowDraftBadge => 'rascunho';

  @override
  String get entryListRowDraftValue => 'rascunho';

  @override
  String entryListRowAudioDraftValue(String description) {
    return 'rascunho, $description';
  }

  @override
  String get entryDetailSaving => 'Salvando alterações...';

  @override
  String get entryDetailSaveFailed =>
      'Não foi possível salvar suas alterações.';

  @override
  String get entryDetailLoadFailed => 'Não foi possível carregar esta entrada.';

  @override
  String get entryDetailEditSemanticsLabel => 'Editar texto da entrada';

  @override
  String get entryDetailEditHint => 'Edite sua entrada';

  @override
  String get entryDetailTapToEditHint => 'Toque para editar a entrada';

  @override
  String get entryDetailBackSemanticsLabel => 'Voltar para as entradas';

  @override
  String get entryDetailBack => 'Voltar';

  @override
  String get entryDetailFinishEditingSemanticsLabel => 'Concluir edição';

  @override
  String get entryDetailEditEntrySemanticsLabel => 'Editar entrada';

  @override
  String get entryDetailDone => 'Concluir';

  @override
  String get entryDetailEdit => 'Editar';

  @override
  String get entryDetailShareSemanticsLabel => 'Compartilhar entrada';

  @override
  String get entryDetailShare => 'Compartilhar';

  @override
  String get entryDetailDeleteSemanticsLabel => 'Excluir entrada';

  @override
  String get entryDetailDelete => 'Excluir';

  @override
  String get entryDetailShareFailed =>
      'Não foi possível compartilhar esta entrada.';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count palavras',
      one: '1 palavra',
    );
    return '$_temp0';
  }

  @override
  String get deleteDialogTitle => 'Excluir entrada?';

  @override
  String get deleteDialogBody => 'Esta entrada será removida permanentemente.';

  @override
  String get deleteCancel => 'Cancelar';

  @override
  String get deleteConfirm => 'Excluir';

  @override
  String get deleteCancelSemanticsLabel => 'Cancelar exclusão';

  @override
  String get deleteCancelSemanticsHint => 'Mantém esta entrada na lista.';

  @override
  String get deleteConfirmSemanticsLabel => 'Excluir entrada permanentemente';

  @override
  String get deleteConfirmSemanticsHint => 'Remove esta entrada da lista.';

  @override
  String get appLockTitle => 'o wrait está bloqueado';

  @override
  String get appLockSemanticsLabel => 'O wrait está bloqueado.';

  @override
  String get appLockUnlock => 'Desbloquear';

  @override
  String get appLockOpenSettings => 'Abrir ajustes';

  @override
  String get appLockContinueWithout => 'Continuar sem bloqueio';

  @override
  String get appLockStillLocked => 'ainda bloqueado';

  @override
  String get appLockSetUpSecurity =>
      'configure a segurança do dispositivo para proteger o wrait';

  @override
  String get appLockUnavailableTryAgain =>
      'desbloqueio indisponível · tente novamente';

  @override
  String get appLockUnlockToContinue => 'Desbloqueie o wrait para continuar.';

  @override
  String get appLockSettingsWarning =>
      'Seu diário ficará visível até que você configure a segurança do dispositivo.';

  @override
  String get appLockSemanticsHintUnlock =>
      'Toque duas vezes em Desbloquear para se autenticar e continuar.';

  @override
  String get appLockSemanticsHintSettings =>
      'Toque duas vezes em Desbloquear para tentar de novo ou abra os ajustes para configurar a segurança do dispositivo.';

  @override
  String get appLockSemanticsHintAuthInProgress => 'Autenticação em andamento.';

  @override
  String get appLockPreferenceLoadFailed =>
      'O wrait não conseguiu carregar sua configuração de privacidade.';

  @override
  String get appLockPreferenceLoading =>
      'carregando configurações de privacidade';

  @override
  String get appLockPreferenceRetry => 'Tentar de novo';

  @override
  String get feedbackTitle => 'enviar feedback';

  @override
  String get feedbackPrompt => 'O que você gostaria de compartilhar?';

  @override
  String get feedbackContactLabel => 'contato para resposta (opcional)';

  @override
  String get feedbackContactHint => 'qualquer informação de contato';

  @override
  String get feedbackMessageLabel => 'feedback';

  @override
  String get feedbackMessageHint => 'o que você gostaria de compartilhar?';

  @override
  String get feedbackPrivacyCopy =>
      'Não inclua conteúdo privado do seu diário, a menos que você escolha digitá-lo na mensagem.';

  @override
  String get feedbackCancel => 'cancelar';

  @override
  String get feedbackSubmit => 'enviar';

  @override
  String get feedbackDismissLabel => 'Dispensar feedback';

  @override
  String get feedbackCategoryBug => 'Bug';

  @override
  String get feedbackCategoryIdea => 'Ideia';

  @override
  String get feedbackCategoryConfusing => 'Confuso';

  @override
  String get feedbackCategoryPraise => 'Elogio';
}
