// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get bootstrapTitle => 'abriendo wrait';

  @override
  String get bootstrapSubtitle => 'cargando tu diario local';

  @override
  String get bootstrapErrorTitle => 'no se pudo abrir wrait';

  @override
  String get bootstrapErrorSubtitle => 'inténtalo de nuevo';

  @override
  String get bootstrapRetryButton => 'reintentar';

  @override
  String get mainSettingsTooltip => 'Ajustes';

  @override
  String get mainFeedbackTooltip => 'Enviar comentarios';

  @override
  String mainLanguageLabel(String displayName) {
    return 'Idioma: $displayName';
  }

  @override
  String get mainLanguageUnavailable =>
      'Idioma no disponible · inténtalo de nuevo';

  @override
  String get mainFeedbackSent => 'comentarios enviados';

  @override
  String get mainFeedbackUnavailable =>
      'los comentarios no están disponibles por ahora';

  @override
  String get mainFeedbackFailed =>
      'no se pudieron enviar los comentarios. inténtalo de nuevo';

  @override
  String mainLanguageSemanticsLabel(String displayName) {
    return 'Idioma de transcripción seleccionado: $displayName. Abre los ajustes del idioma de transcripción.';
  }

  @override
  String get mainSettingsSemanticsLabel => 'Ajustes';

  @override
  String get mainFeedbackSemanticsLabel => 'Enviar comentarios';

  @override
  String mainQuotaSemanticsLabel(int limit, int remaining) {
    return 'Cuota de grabación: $limit en total y $remaining restantes.';
  }

  @override
  String mainQuotaText(int limit, int remaining) {
    return '$limit en total / $remaining restantes';
  }

  @override
  String get mainButtonStop => 'detener';

  @override
  String get mainButtonWrait => 'wrait';

  @override
  String get statusTapToWrite => 'toca el botón para escribir';

  @override
  String get statusWrait => 'wrait';

  @override
  String get statusListening => 'escuchando...';

  @override
  String get statusProcessing => 'procesando...';

  @override
  String get statusCleaningUp => 'limpiando el texto...';

  @override
  String get statusSavedTapToRead => 'guardado, toca para leer';

  @override
  String get statusDeleted => 'eliminado';

  @override
  String get statusNoConnectionDraft => 'sin conexión · guardado como borrador';

  @override
  String get statusServiceUnavailableDraft =>
      'servicio no disponible · guardado como borrador';

  @override
  String get statusServerConfigErrorDraft =>
      'error de configuración del servidor · guardado como borrador';

  @override
  String get statusSpeechNotRecognizedDraft =>
      'no se reconoció · guardado como borrador';

  @override
  String get statusSpeechNotRecognized => 'no se reconoció';

  @override
  String get statusApiFailedDraft => 'guardado como borrador · se reintentará';

  @override
  String get statusTooShort => 'muy corto · sigue hablando';

  @override
  String get statusNothingCaught => 'no se captó nada · ¿hablaste muy bajo?';

  @override
  String get statusMicNeeded => 'se necesita el micrófono · toca otra vez';

  @override
  String get statusMicBlocked => 'micrófono bloqueado · toca ajustes';

  @override
  String get statusNoConnection => 'sin conexión';

  @override
  String get statusServiceUnavailable => 'servicio no disponible';

  @override
  String get statusServerConfigError => 'error de configuración del servidor';

  @override
  String get statusSomethingWentWrong => 'algo salió mal';

  @override
  String get statusMicNeededSemanticsLabel =>
      'Se necesita acceso al micrófono para empezar a grabar.';

  @override
  String get statusMicNeededSemanticsHint =>
      'Toca dos veces para volver a solicitar acceso al micrófono.';

  @override
  String get statusMicBlockedSemanticsLabel =>
      'El acceso al micrófono está bloqueado para Wrait.';

  @override
  String get statusMicBlockedSemanticsHint =>
      'Toca dos veces para abrir los ajustes de la app.';

  @override
  String statusDefaultSemanticsLabel(String statusText) {
    return 'Mensaje de estado: $statusText.';
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
      other: '$count días',
      one: '$count día',
    );
    return '$_temp0';
  }

  @override
  String statsDisplay(String entries, String days) {
    return '$entries - $days';
  }

  @override
  String statsSemanticsLabel(String displayText) {
    return 'Estadísticas de entradas: $displayText. Abre la lista de entradas.';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsBack => 'Atrás';

  @override
  String get settingsPrivacy => 'Privacidad';

  @override
  String get settingsAppLock => 'Bloqueo de la app';

  @override
  String get settingsAppLockDescription =>
      'Usa el bloqueo de pantalla de tu dispositivo cuando abras Wrait o vuelvas a ella.';

  @override
  String get settingsAppLockUnavailable =>
      'El bloqueo de la app no está disponible en esta versión de validación.';

  @override
  String get settingsAppLockNoSecurity =>
      'Configura un bloqueo de pantalla en tu dispositivo antes de activar el bloqueo de la app.';

  @override
  String get settingsAppLockTemporarilyUnavailable =>
      'La autenticación del dispositivo no está disponible por el momento. Inténtalo de nuevo.';

  @override
  String get settingsAppLockUnavailableDevice =>
      'La autenticación del dispositivo no está disponible en este dispositivo.';

  @override
  String get settingsAppLockSaveFailed =>
      'No se pudo guardar el ajuste del bloqueo de la app. Inténtalo de nuevo.';

  @override
  String get settingsAppLockSettingsFailed =>
      'No se pudieron abrir los ajustes de seguridad del dispositivo.';

  @override
  String get settingsOpenDeviceSettings => 'Abrir ajustes del dispositivo';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsThemeSaveFailed =>
      'No se pudo guardar el tema. Inténtalo de nuevo.';

  @override
  String get settingsReminders => 'Recordatorios';

  @override
  String get settingsRemindersToggle => 'Recordatorios diarios';

  @override
  String get settingsRemindersDescription =>
      'Recibe recordatorios para escribir en tu diario por la mañana y por la noche';

  @override
  String get settingsRemindersPermissionDenied =>
      'Se necesita permiso de notificaciones para los recordatorios. Actívalo en los ajustes del dispositivo.';

  @override
  String get reminderMorningTitle => 'wrait';

  @override
  String get reminderMorningBody => 'Comienza tu día con una reflexión';

  @override
  String get reminderEveningTitle => 'wrait';

  @override
  String get reminderEveningBody => 'Aún te quedan grabaciones hoy';

  @override
  String get settingsTranscriptionLanguage => 'Idioma de transcripción';

  @override
  String get settingsTranscriptionLanguageDescription =>
      'Elige el idioma en el que hablas para mejorar la transcripción. Si no seleccionas ningún idioma, se usará la detección automática.';

  @override
  String get settingsAutomaticDetection => 'Detección automática';

  @override
  String get settingsLoading => 'Cargando…';

  @override
  String get settingsTranscriptionLanguageLoadFailed =>
      'No se pudo cargar el idioma de transcripción.';

  @override
  String get settingsTranscriptionLanguageSaveFailed =>
      'No se pudo guardar el idioma. Inténtalo de nuevo.';

  @override
  String get settingsTryAgain => 'Inténtalo de nuevo';

  @override
  String get settingsActivityMessage =>
      'Termina la grabación o transcripción actual antes de cambiar los ajustes.';

  @override
  String get entryListBack => 'Atrás';

  @override
  String get entryListBackSemanticsLabel => 'Volver a la pantalla principal';

  @override
  String get entryListSearchLabel => 'Buscar entradas';

  @override
  String get entryListClearSearch => 'Borrar búsqueda';

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
  String get entryListEmpty => 'aún no hay entradas';

  @override
  String get entryListNoResults => 'No hay entradas que coincidan';

  @override
  String entryListExportSuccess(String fileName, String pathLabel) {
    return 'Se exportó $fileName en $pathLabel.';
  }

  @override
  String get entryListExportFailed => 'No se pudieron exportar las entradas.';

  @override
  String entryListImportSuccess(int count, String fileName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'importaron',
      one: 'importó',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'registros',
      one: 'registro',
    );
    return 'Se $_temp0 $count $_temp1 de $fileName.';
  }

  @override
  String get entryListImportFailed => 'No se pudieron importar las entradas.';

  @override
  String get entryListImportInvalidFormat =>
      'El CSV seleccionado no es una exportación válida de Wrait.';

  @override
  String get entryListImportUnreadableFile =>
      'No se pudo leer el archivo CSV seleccionado.';

  @override
  String get entryListImportFileTooLarge =>
      'El CSV seleccionado es demasiado grande para importarlo.';

  @override
  String get entryListImportStorageFailure =>
      'No se pudieron guardar las entradas importadas.';

  @override
  String get entryListAudioDraftPreview => 'pendiente · se reintentará';

  @override
  String get entryListAudioDraftStateDescription =>
      'Borrador de audio, aún sin transcribir';

  @override
  String get entryListDeleteActionLabel => 'Eliminar entrada';

  @override
  String entryListRowSemanticsLabel(String timestamp, String languageLabel) {
    return 'Entrada $timestamp. $languageLabel.';
  }

  @override
  String get entryListRowSwipeHint => 'Desliza hacia la derecha para eliminar.';

  @override
  String get entryListRowOpenHint =>
      'Toca dos veces para abrir. Desliza hacia la derecha para eliminar.';

  @override
  String get entryListRowDraftBadge => 'borrador';

  @override
  String get entryListRowDraftValue => 'borrador';

  @override
  String entryListRowAudioDraftValue(String description) {
    return 'borrador, $description';
  }

  @override
  String get entryDetailSaving => 'Guardando cambios...';

  @override
  String get entryDetailSaveFailed => 'No se pudieron guardar tus cambios.';

  @override
  String get entryDetailLoadFailed => 'No se pudo cargar esta entrada.';

  @override
  String get entryDetailEditSemanticsLabel => 'Editar el texto de la entrada';

  @override
  String get entryDetailEditHint => 'Edita tu entrada';

  @override
  String get entryDetailTapToEditHint => 'Toca para editar la entrada';

  @override
  String get entryDetailBackSemanticsLabel => 'Volver a las entradas';

  @override
  String get entryDetailBack => 'Atrás';

  @override
  String get entryDetailFinishEditingSemanticsLabel => 'Terminar de editar';

  @override
  String get entryDetailEditEntrySemanticsLabel => 'Editar entrada';

  @override
  String get entryDetailDone => 'Listo';

  @override
  String get entryDetailEdit => 'Editar';

  @override
  String get entryDetailShareSemanticsLabel => 'Compartir entrada';

  @override
  String get entryDetailShare => 'Compartir';

  @override
  String get entryDetailDeleteSemanticsLabel => 'Eliminar entrada';

  @override
  String get entryDetailDelete => 'Eliminar';

  @override
  String get entryDetailShareFailed => 'No se pudo compartir esta entrada.';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count palabras',
      one: '1 palabra',
    );
    return '$_temp0';
  }

  @override
  String get deleteDialogTitle => '¿Eliminar entrada?';

  @override
  String get deleteDialogBody =>
      'Esta entrada se eliminará de forma permanente.';

  @override
  String get deleteCancel => 'Cancelar';

  @override
  String get deleteConfirm => 'Eliminar';

  @override
  String get deleteCancelSemanticsLabel => 'Cancelar eliminación';

  @override
  String get deleteCancelSemanticsHint => 'Mantiene esta entrada en la lista.';

  @override
  String get deleteConfirmSemanticsLabel =>
      'Eliminar entrada de forma permanente';

  @override
  String get deleteConfirmSemanticsHint => 'Quita esta entrada de la lista.';

  @override
  String get appLockTitle => 'wrait está bloqueado';

  @override
  String get appLockSemanticsLabel => 'Wrait está bloqueado.';

  @override
  String get appLockUnlock => 'Desbloquear';

  @override
  String get appLockOpenSettings => 'Abrir ajustes';

  @override
  String get appLockContinueWithout => 'Continuar sin bloqueo';

  @override
  String get appLockStillLocked => 'sigue bloqueado';

  @override
  String get appLockSetUpSecurity =>
      'configura la seguridad del dispositivo para proteger Wrait';

  @override
  String get appLockUnavailableTryAgain =>
      'desbloqueo no disponible · inténtalo de nuevo';

  @override
  String get appLockUnlockToContinue => 'Desbloquea Wrait para continuar.';

  @override
  String get appLockSettingsWarning =>
      'Tu diario estará visible hasta que configures la seguridad del dispositivo.';

  @override
  String get appLockSemanticsHintUnlock =>
      'Toca dos veces Desbloquear para autenticarte y continuar.';

  @override
  String get appLockSemanticsHintSettings =>
      'Toca dos veces Desbloquear para intentarlo de nuevo, o abre los ajustes para configurar la seguridad del dispositivo.';

  @override
  String get appLockSemanticsHintAuthInProgress =>
      'La autenticación está en curso.';

  @override
  String get appLockPreferenceLoadFailed =>
      'Wrait no pudo cargar tu ajuste de privacidad.';

  @override
  String get appLockPreferenceLoading => 'cargando ajustes de privacidad';

  @override
  String get appLockPreferenceRetry => 'Inténtalo de nuevo';

  @override
  String get feedbackTitle => 'enviar comentarios';

  @override
  String get feedbackPrompt => '¿Qué te gustaría compartir?';

  @override
  String get feedbackContactLabel => 'contacto para responderte (opcional)';

  @override
  String get feedbackContactHint => 'cualquier dato de contacto';

  @override
  String get feedbackMessageLabel => 'comentarios';

  @override
  String get feedbackMessageHint => '¿qué te gustaría compartir?';

  @override
  String get feedbackPrivacyCopy =>
      'No incluyas contenido privado de tu diario, a menos que decidas escribirlo en tu mensaje.';

  @override
  String get feedbackCancel => 'cancelar';

  @override
  String get feedbackSubmit => 'enviar';

  @override
  String get feedbackDismissLabel => 'Cerrar comentarios';

  @override
  String get feedbackCategoryBug => 'Error';

  @override
  String get feedbackCategoryIdea => 'Idea';

  @override
  String get feedbackCategoryConfusing => 'Confuso';

  @override
  String get feedbackCategoryPraise => 'Elogio';
}

/// The translations for Spanish Castilian, as used in Latin America and the Caribbean (`es_419`).
class AppLocalizationsEs419 extends AppLocalizationsEs {
  AppLocalizationsEs419() : super('es_419');

  @override
  String get bootstrapTitle => 'abriendo wrait';

  @override
  String get bootstrapSubtitle => 'cargando tu diario local';

  @override
  String get bootstrapErrorTitle => 'no se pudo abrir wrait';

  @override
  String get bootstrapErrorSubtitle => 'inténtalo de nuevo';

  @override
  String get bootstrapRetryButton => 'reintentar';

  @override
  String get mainSettingsTooltip => 'Ajustes';

  @override
  String get mainFeedbackTooltip => 'Enviar comentarios';

  @override
  String mainLanguageLabel(String displayName) {
    return 'Idioma: $displayName';
  }

  @override
  String get mainLanguageUnavailable =>
      'Idioma no disponible · inténtalo de nuevo';

  @override
  String get mainFeedbackSent => 'comentarios enviados';

  @override
  String get mainFeedbackUnavailable =>
      'los comentarios no están disponibles por ahora';

  @override
  String get mainFeedbackFailed =>
      'no se pudieron enviar los comentarios. inténtalo de nuevo';

  @override
  String mainLanguageSemanticsLabel(String displayName) {
    return 'Idioma de transcripción seleccionado: $displayName. Abre los ajustes del idioma de transcripción.';
  }

  @override
  String get mainSettingsSemanticsLabel => 'Ajustes';

  @override
  String get mainFeedbackSemanticsLabel => 'Enviar comentarios';

  @override
  String mainQuotaSemanticsLabel(int limit, int remaining) {
    return 'Cuota de grabación: $limit en total y $remaining restantes.';
  }

  @override
  String mainQuotaText(int limit, int remaining) {
    return '$limit en total / $remaining restantes';
  }

  @override
  String get mainButtonStop => 'detener';

  @override
  String get mainButtonWrait => 'wrait';

  @override
  String get statusTapToWrite => 'toca el botón para escribir';

  @override
  String get statusWrait => 'wrait';

  @override
  String get statusListening => 'escuchando...';

  @override
  String get statusProcessing => 'procesando...';

  @override
  String get statusCleaningUp => 'limpiando el texto...';

  @override
  String get statusSavedTapToRead => 'guardado, toca para leer';

  @override
  String get statusDeleted => 'eliminado';

  @override
  String get statusNoConnectionDraft => 'sin conexión · guardado como borrador';

  @override
  String get statusServiceUnavailableDraft =>
      'servicio no disponible · guardado como borrador';

  @override
  String get statusServerConfigErrorDraft =>
      'error de configuración del servidor · guardado como borrador';

  @override
  String get statusSpeechNotRecognizedDraft =>
      'no se reconoció · guardado como borrador';

  @override
  String get statusSpeechNotRecognized => 'no se reconoció';

  @override
  String get statusApiFailedDraft => 'guardado como borrador · se reintentará';

  @override
  String get statusTooShort => 'muy corto · sigue hablando';

  @override
  String get statusNothingCaught => 'no se captó nada · ¿hablaste muy bajo?';

  @override
  String get statusMicNeeded => 'se necesita el micrófono · toca otra vez';

  @override
  String get statusMicBlocked => 'micrófono bloqueado · toca ajustes';

  @override
  String get statusNoConnection => 'sin conexión';

  @override
  String get statusServiceUnavailable => 'servicio no disponible';

  @override
  String get statusServerConfigError => 'error de configuración del servidor';

  @override
  String get statusSomethingWentWrong => 'algo salió mal';

  @override
  String get statusMicNeededSemanticsLabel =>
      'Se necesita acceso al micrófono para empezar a grabar.';

  @override
  String get statusMicNeededSemanticsHint =>
      'Toca dos veces para volver a solicitar acceso al micrófono.';

  @override
  String get statusMicBlockedSemanticsLabel =>
      'El acceso al micrófono está bloqueado para Wrait.';

  @override
  String get statusMicBlockedSemanticsHint =>
      'Toca dos veces para abrir los ajustes de la app.';

  @override
  String statusDefaultSemanticsLabel(String statusText) {
    return 'Mensaje de estado: $statusText.';
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
      other: '$count días',
      one: '$count día',
    );
    return '$_temp0';
  }

  @override
  String statsDisplay(String entries, String days) {
    return '$entries - $days';
  }

  @override
  String statsSemanticsLabel(String displayText) {
    return 'Estadísticas de entradas: $displayText. Abre la lista de entradas.';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsBack => 'Atrás';

  @override
  String get settingsPrivacy => 'Privacidad';

  @override
  String get settingsAppLock => 'Bloqueo de la app';

  @override
  String get settingsAppLockDescription =>
      'Usa el bloqueo de pantalla de tu dispositivo cuando abras Wrait o vuelvas a ella.';

  @override
  String get settingsAppLockUnavailable =>
      'El bloqueo de la app no está disponible en esta versión de validación.';

  @override
  String get settingsAppLockNoSecurity =>
      'Configura un bloqueo de pantalla en tu dispositivo antes de activar el bloqueo de la app.';

  @override
  String get settingsAppLockTemporarilyUnavailable =>
      'La autenticación del dispositivo no está disponible por el momento. Inténtalo de nuevo.';

  @override
  String get settingsAppLockUnavailableDevice =>
      'La autenticación del dispositivo no está disponible en este dispositivo.';

  @override
  String get settingsAppLockSaveFailed =>
      'No se pudo guardar el ajuste del bloqueo de la app. Inténtalo de nuevo.';

  @override
  String get settingsAppLockSettingsFailed =>
      'No se pudieron abrir los ajustes de seguridad del dispositivo.';

  @override
  String get settingsOpenDeviceSettings => 'Abrir ajustes del dispositivo';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsThemeSaveFailed =>
      'No se pudo guardar el tema. Inténtalo de nuevo.';

  @override
  String get settingsReminders => 'Recordatorios';

  @override
  String get settingsRemindersToggle => 'Recordatorios diarios';

  @override
  String get settingsRemindersDescription =>
      'Recibe recordatorios para escribir en tu diario por la mañana y por la noche';

  @override
  String get settingsRemindersPermissionDenied =>
      'Se necesita permiso de notificaciones para los recordatorios. Actívalo en los ajustes del dispositivo.';

  @override
  String get reminderMorningTitle => 'wrait';

  @override
  String get reminderMorningBody => 'Comienza tu día con una reflexión';

  @override
  String get reminderEveningTitle => 'wrait';

  @override
  String get reminderEveningBody => 'Aún te quedan grabaciones hoy';

  @override
  String get settingsTranscriptionLanguage => 'Idioma de transcripción';

  @override
  String get settingsTranscriptionLanguageDescription =>
      'Elige el idioma en el que hablas para mejorar la transcripción. Si no seleccionas ningún idioma, se usará la detección automática.';

  @override
  String get settingsAutomaticDetection => 'Detección automática';

  @override
  String get settingsLoading => 'Cargando…';

  @override
  String get settingsTranscriptionLanguageLoadFailed =>
      'No se pudo cargar el idioma de transcripción.';

  @override
  String get settingsTranscriptionLanguageSaveFailed =>
      'No se pudo guardar el idioma. Inténtalo de nuevo.';

  @override
  String get settingsTryAgain => 'Inténtalo de nuevo';

  @override
  String get settingsActivityMessage =>
      'Termina la grabación o transcripción actual antes de cambiar los ajustes.';

  @override
  String get entryListBack => 'Atrás';

  @override
  String get entryListBackSemanticsLabel => 'Volver a la pantalla principal';

  @override
  String get entryListSearchLabel => 'Buscar entradas';

  @override
  String get entryListClearSearch => 'Borrar búsqueda';

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
  String get entryListEmpty => 'aún no hay entradas';

  @override
  String get entryListNoResults => 'No hay entradas que coincidan';

  @override
  String entryListExportSuccess(String fileName, String pathLabel) {
    return 'Se exportó $fileName en $pathLabel.';
  }

  @override
  String get entryListExportFailed => 'No se pudieron exportar las entradas.';

  @override
  String entryListImportSuccess(int count, String fileName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'importaron',
      one: 'importó',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'registros',
      one: 'registro',
    );
    return 'Se $_temp0 $count $_temp1 de $fileName.';
  }

  @override
  String get entryListImportFailed => 'No se pudieron importar las entradas.';

  @override
  String get entryListImportInvalidFormat =>
      'El CSV seleccionado no es una exportación válida de Wrait.';

  @override
  String get entryListImportUnreadableFile =>
      'No se pudo leer el archivo CSV seleccionado.';

  @override
  String get entryListImportFileTooLarge =>
      'El CSV seleccionado es demasiado grande para importarlo.';

  @override
  String get entryListImportStorageFailure =>
      'No se pudieron guardar las entradas importadas.';

  @override
  String get entryListAudioDraftPreview => 'pendiente · se reintentará';

  @override
  String get entryListAudioDraftStateDescription =>
      'Borrador de audio, aún sin transcribir';

  @override
  String get entryListDeleteActionLabel => 'Eliminar entrada';

  @override
  String entryListRowSemanticsLabel(String timestamp, String languageLabel) {
    return 'Entrada $timestamp. $languageLabel.';
  }

  @override
  String get entryListRowSwipeHint => 'Desliza hacia la derecha para eliminar.';

  @override
  String get entryListRowOpenHint =>
      'Toca dos veces para abrir. Desliza hacia la derecha para eliminar.';

  @override
  String get entryListRowDraftBadge => 'borrador';

  @override
  String get entryListRowDraftValue => 'borrador';

  @override
  String entryListRowAudioDraftValue(String description) {
    return 'borrador, $description';
  }

  @override
  String get entryDetailSaving => 'Guardando cambios...';

  @override
  String get entryDetailSaveFailed => 'No se pudieron guardar tus cambios.';

  @override
  String get entryDetailLoadFailed => 'No se pudo cargar esta entrada.';

  @override
  String get entryDetailEditSemanticsLabel => 'Editar el texto de la entrada';

  @override
  String get entryDetailEditHint => 'Edita tu entrada';

  @override
  String get entryDetailTapToEditHint => 'Toca para editar la entrada';

  @override
  String get entryDetailBackSemanticsLabel => 'Volver a las entradas';

  @override
  String get entryDetailBack => 'Atrás';

  @override
  String get entryDetailFinishEditingSemanticsLabel => 'Terminar de editar';

  @override
  String get entryDetailEditEntrySemanticsLabel => 'Editar entrada';

  @override
  String get entryDetailDone => 'Listo';

  @override
  String get entryDetailEdit => 'Editar';

  @override
  String get entryDetailShareSemanticsLabel => 'Compartir entrada';

  @override
  String get entryDetailShare => 'Compartir';

  @override
  String get entryDetailDeleteSemanticsLabel => 'Eliminar entrada';

  @override
  String get entryDetailDelete => 'Eliminar';

  @override
  String get entryDetailShareFailed => 'No se pudo compartir esta entrada.';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count palabras',
      one: '1 palabra',
    );
    return '$_temp0';
  }

  @override
  String get deleteDialogTitle => '¿Eliminar entrada?';

  @override
  String get deleteDialogBody =>
      'Esta entrada se eliminará de forma permanente.';

  @override
  String get deleteCancel => 'Cancelar';

  @override
  String get deleteConfirm => 'Eliminar';

  @override
  String get deleteCancelSemanticsLabel => 'Cancelar eliminación';

  @override
  String get deleteCancelSemanticsHint => 'Mantiene esta entrada en la lista.';

  @override
  String get deleteConfirmSemanticsLabel =>
      'Eliminar entrada de forma permanente';

  @override
  String get deleteConfirmSemanticsHint => 'Quita esta entrada de la lista.';

  @override
  String get appLockTitle => 'wrait está bloqueado';

  @override
  String get appLockSemanticsLabel => 'Wrait está bloqueado.';

  @override
  String get appLockUnlock => 'Desbloquear';

  @override
  String get appLockOpenSettings => 'Abrir ajustes';

  @override
  String get appLockContinueWithout => 'Continuar sin bloqueo';

  @override
  String get appLockStillLocked => 'sigue bloqueado';

  @override
  String get appLockSetUpSecurity =>
      'configura la seguridad del dispositivo para proteger Wrait';

  @override
  String get appLockUnavailableTryAgain =>
      'desbloqueo no disponible · inténtalo de nuevo';

  @override
  String get appLockUnlockToContinue => 'Desbloquea Wrait para continuar.';

  @override
  String get appLockSettingsWarning =>
      'Tu diario estará visible hasta que configures la seguridad del dispositivo.';

  @override
  String get appLockSemanticsHintUnlock =>
      'Toca dos veces Desbloquear para autenticarte y continuar.';

  @override
  String get appLockSemanticsHintSettings =>
      'Toca dos veces Desbloquear para intentarlo de nuevo, o abre los ajustes para configurar la seguridad del dispositivo.';

  @override
  String get appLockSemanticsHintAuthInProgress =>
      'La autenticación está en curso.';

  @override
  String get appLockPreferenceLoadFailed =>
      'Wrait no pudo cargar tu ajuste de privacidad.';

  @override
  String get appLockPreferenceLoading => 'cargando ajustes de privacidad';

  @override
  String get appLockPreferenceRetry => 'Inténtalo de nuevo';

  @override
  String get feedbackTitle => 'enviar comentarios';

  @override
  String get feedbackPrompt => '¿Qué te gustaría compartir?';

  @override
  String get feedbackContactLabel => 'contacto para responderte (opcional)';

  @override
  String get feedbackContactHint => 'cualquier dato de contacto';

  @override
  String get feedbackMessageLabel => 'comentarios';

  @override
  String get feedbackMessageHint => '¿qué te gustaría compartir?';

  @override
  String get feedbackPrivacyCopy =>
      'No incluyas contenido privado de tu diario, a menos que decidas escribirlo en tu mensaje.';

  @override
  String get feedbackCancel => 'cancelar';

  @override
  String get feedbackSubmit => 'enviar';

  @override
  String get feedbackDismissLabel => 'Cerrar comentarios';

  @override
  String get feedbackCategoryBug => 'Error';

  @override
  String get feedbackCategoryIdea => 'Idea';

  @override
  String get feedbackCategoryConfusing => 'Confuso';

  @override
  String get feedbackCategoryPraise => 'Elogio';
}
