class AppConfig {
  static const String backendUrlDefine = 'BACKEND_URL';
  static const String proxySecretDefine = 'PROXY_SECRET';
  static const String recordingHardCapMsDefine = 'RECORDING_HARD_CAP_MS';
  static const String wiredashProjectIdDefine = 'WIREDASH_PROJECT_ID';
  static const String wiredashSecretDefine = 'WIREDASH_SECRET';
  static const String wiredashEnvironmentDefine = 'WIREDASH_ENVIRONMENT';
  static const String debugDeviceIdDefine = 'DEBUG_DEVICE_ID';

  static const String defaultBackendUrl = 'https://wrait-backend.vercel.app';
  static const String defaultRecordingHardCapMs = '120000';
  static const String defaultWiredashEnvironment = 'dev';

  const AppConfig({
    required this.backendUrl,
    required this.proxySecret,
    required this.recordingHardCapMs,
    this.wiredashProjectId = '',
    this.wiredashSecret = '',
    this.wiredashEnvironment = defaultWiredashEnvironment,
    this.debugDeviceId = '',
  });

  final String backendUrl;
  final String proxySecret;
  final int recordingHardCapMs;
  final String wiredashProjectId;
  final String wiredashSecret;
  final String wiredashEnvironment;
  final String debugDeviceId;

  bool get wiredashConfigured =>
      wiredashProjectId.trim().isNotEmpty && wiredashSecret.trim().isNotEmpty;

  bool get isDebugDeviceConfigured => debugDeviceId.isNotEmpty;

  Uri get backendUri => Uri.parse(backendUrl);

  factory AppConfig.fromEnvironment() {
    return AppConfig.fromValues(
      backendUrl: const String.fromEnvironment(
        backendUrlDefine,
        defaultValue: defaultBackendUrl,
      ),
      proxySecret: const String.fromEnvironment(
        proxySecretDefine,
        defaultValue: '',
      ),
      recordingHardCapMs: const String.fromEnvironment(
        recordingHardCapMsDefine,
        defaultValue: defaultRecordingHardCapMs,
      ),
      wiredashProjectId: const String.fromEnvironment(
        wiredashProjectIdDefine,
        defaultValue: '',
      ),
      wiredashSecret: const String.fromEnvironment(
        wiredashSecretDefine,
        defaultValue: '',
      ),
      wiredashEnvironment: const String.fromEnvironment(
        wiredashEnvironmentDefine,
        defaultValue: defaultWiredashEnvironment,
      ),
      debugDeviceId: const String.fromEnvironment(
        debugDeviceIdDefine,
        defaultValue: '',
      ),
    );
  }

  factory AppConfig.fromValues({
    String? backendUrl,
    String? proxySecret,
    String? recordingHardCapMs,
    String? wiredashProjectId,
    String? wiredashSecret,
    String? wiredashEnvironment,
    String? debugDeviceId,
  }) {
    final resolvedBackendUrl = (backendUrl ?? defaultBackendUrl).trim();
    final resolvedProxySecret = (proxySecret ?? '').trim();
    final resolvedHardCapRaw = (recordingHardCapMs ?? defaultRecordingHardCapMs)
        .trim();
    final resolvedWiredashProjectId = (wiredashProjectId ?? '').trim();
    final resolvedWiredashSecret = (wiredashSecret ?? '').trim();
    final resolvedWiredashEnvironment =
        (wiredashEnvironment ?? defaultWiredashEnvironment).trim();
    final resolvedDebugDeviceId = (debugDeviceId ?? '').trim();

    final parsedBackendUri = Uri.tryParse(resolvedBackendUrl);
    if (parsedBackendUri == null ||
        !parsedBackendUri.hasScheme ||
        parsedBackendUri.host.isEmpty) {
      throw FormatException(
        'Invalid $backendUrlDefine value: "$resolvedBackendUrl". Expected an absolute URL.',
      );
    }

    final parsedHardCap = int.tryParse(resolvedHardCapRaw);
    if (parsedHardCap == null || parsedHardCap <= 0) {
      throw FormatException(
        'Invalid $recordingHardCapMsDefine value: "$resolvedHardCapRaw". Expected a positive integer.',
      );
    }

    return AppConfig(
      backendUrl: parsedBackendUri.toString(),
      proxySecret: resolvedProxySecret,
      recordingHardCapMs: parsedHardCap,
      wiredashProjectId: resolvedWiredashProjectId,
      wiredashSecret: resolvedWiredashSecret,
      wiredashEnvironment: resolvedWiredashEnvironment.isEmpty
          ? defaultWiredashEnvironment
          : resolvedWiredashEnvironment,
      debugDeviceId: resolvedDebugDeviceId,
    );
  }
}
