import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:wrait_backend_api/wrait_backend_api.dart' as openapi;

const generatedBackendApiSpecPath = 'api/wrait-backend.yaml';

sealed class GeneratedApiResponse<T> {
  const GeneratedApiResponse({required this.statusCode});

  final int statusCode;
}

final class GeneratedApiSuccess<T> extends GeneratedApiResponse<T> {
  const GeneratedApiSuccess({required super.statusCode, required this.data});

  final T data;
}

final class GeneratedApiFailure<T> extends GeneratedApiResponse<T> {
  const GeneratedApiFailure({required super.statusCode, required this.data});

  final dynamic data;
}

abstract interface class GeneratedBackendApiClient {
  Future<GeneratedApiResponse<RegisterResponse>> registerDevice({
    required String xDeviceId,
  });

  Future<GeneratedApiResponse<TranscribeResponse>> transcribeAudio({
    required String xDeviceId,
    required List<int> audioBytes,
    required String audioFilename,
    String? language,
  });

  Future<GeneratedApiResponse<CleanupResponse>> cleanupTranscript({
    required String xDeviceId,
    required CleanupRequest cleanupRequest,
  });

  Future<GeneratedApiResponse<TagResponse>> tagText({
    required String xDeviceId,
    required TagRequest tagRequest,
  });
}

class DioGeneratedBackendApiClient implements GeneratedBackendApiClient {
  DioGeneratedBackendApiClient(this._dio);

  final Dio _dio;

  @override
  Future<GeneratedApiResponse<RegisterResponse>> registerDevice({
    required String xDeviceId,
  }) async {
    final response = await _dio.request<dynamic>(
      '/api/register',
      options: Options(
        method: 'POST',
        responseType: ResponseType.json,
        validateStatus: (_) => true,
        headers: <String, dynamic>{'X-Device-Id': xDeviceId},
      ),
    );

    final normalizedData = _normalizeResponseData(response.data);
    if (response.statusCode == 201) {
      return GeneratedApiSuccess<RegisterResponse>(
        statusCode: response.statusCode ?? 201,
        data: RegisterResponse.fromJson(
          _asJsonMap(normalizedData, 'registerDevice success body'),
        ),
      );
    }

    return GeneratedApiFailure<RegisterResponse>(
      statusCode: response.statusCode ?? 0,
      data: normalizedData,
    );
  }

  @override
  Future<GeneratedApiResponse<TranscribeResponse>> transcribeAudio({
    required String xDeviceId,
    required List<int> audioBytes,
    required String audioFilename,
    String? language,
  }) async {
    final response = await _dio.request<dynamic>(
      '/api/transcribe',
      queryParameters: language == null
          ? null
          : <String, dynamic>{'language': language},
      data: FormData.fromMap(<String, dynamic>{
        'audio': MultipartFile.fromBytes(audioBytes, filename: audioFilename),
      }),
      options: Options(
        method: 'POST',
        responseType: ResponseType.json,
        validateStatus: (_) => true,
        headers: <String, dynamic>{'X-Device-Id': xDeviceId},
      ),
    );

    final normalizedData = _normalizeResponseData(response.data);
    if (response.statusCode == 200) {
      return GeneratedApiSuccess<TranscribeResponse>(
        statusCode: response.statusCode ?? 200,
        data: TranscribeResponse.fromJson(
          _asJsonMap(normalizedData, 'transcribeAudio success body'),
        ),
      );
    }

    return GeneratedApiFailure<TranscribeResponse>(
      statusCode: response.statusCode ?? 0,
      data: normalizedData,
    );
  }

  @override
  Future<GeneratedApiResponse<CleanupResponse>> cleanupTranscript({
    required String xDeviceId,
    required CleanupRequest cleanupRequest,
  }) async {
    final response = await _dio.request<dynamic>(
      '/api/cleanup',
      data: cleanupRequest.toJson(),
      options: Options(
        method: 'POST',
        responseType: ResponseType.json,
        validateStatus: (_) => true,
        headers: <String, dynamic>{'X-Device-Id': xDeviceId},
      ),
    );

    final normalizedData = _normalizeResponseData(response.data);
    if (response.statusCode == 200) {
      return GeneratedApiSuccess<CleanupResponse>(
        statusCode: response.statusCode ?? 200,
        data: CleanupResponse.fromJson(
          _asJsonMap(normalizedData, 'cleanupTranscript success body'),
        ),
      );
    }

    return GeneratedApiFailure<CleanupResponse>(
      statusCode: response.statusCode ?? 0,
      data: normalizedData,
    );
  }

  @override
  Future<GeneratedApiResponse<TagResponse>> tagText({
    required String xDeviceId,
    required TagRequest tagRequest,
  }) async {
    final response = await _dio.request<dynamic>(
      '/api/tag',
      data: tagRequest.toJson(),
      options: Options(
        method: 'POST',
        responseType: ResponseType.json,
        validateStatus: (_) => true,
        headers: <String, dynamic>{'X-Device-Id': xDeviceId},
      ),
    );

    final normalizedData = _normalizeResponseData(response.data);
    if (response.statusCode == 200) {
      return GeneratedApiSuccess<TagResponse>(
        statusCode: response.statusCode ?? 200,
        data: TagResponse.fromJson(
          _asJsonMap(normalizedData, 'tagText success body'),
        ),
      );
    }

    return GeneratedApiFailure<TagResponse>(
      statusCode: response.statusCode ?? 0,
      data: normalizedData,
    );
  }
}

class ErrorResponse {
  const ErrorResponse({required this.error});

  final String error;

  factory ErrorResponse.fromJson(Map<String, dynamic> json) {
    final parsed = _deserializeGenerated(
      openapi.ErrorResponse.serializer,
      json,
      'ErrorResponse',
    );
    return ErrorResponse(error: parsed.error);
  }
}

class DailyRecordLimitExceededResponse {
  const DailyRecordLimitExceededResponse({
    required this.error,
    required this.quota,
  });

  final String error;
  final RecordQuota quota;

  factory DailyRecordLimitExceededResponse.fromJson(Map<String, dynamic> json) {
    final parsed = _deserializeGenerated(
      openapi.DailyRecordLimitExceededResponse.serializer,
      json,
      'DailyRecordLimitExceededResponse',
    );
    return DailyRecordLimitExceededResponse(
      error: 'Daily record limit exceeded',
      quota: RecordQuota.fromOpenApi(parsed.quota),
    );
  }
}

class RecordQuota {
  const RecordQuota({
    required this.limit,
    required this.count,
    required this.remaining,
    required this.resetAt,
  });

  final int limit;
  final int count;
  final int remaining;
  final DateTime resetAt;

  factory RecordQuota.fromJson(Map<String, dynamic> json) {
    final parsed = _deserializeGenerated(
      openapi.RecordQuota.serializer,
      json,
      'RecordQuota',
    );
    return RecordQuota.fromOpenApi(parsed);
  }

  factory RecordQuota.fromOpenApi(openapi.RecordQuota value) {
    return RecordQuota(
      limit: value.limit,
      count: value.count,
      remaining: value.remaining,
      resetAt: value.resetAt,
    );
  }
}

class RegisterResponse {
  const RegisterResponse({required this.ok, this.quota});

  final bool ok;
  final RecordQuota? quota;

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    final parsed = _deserializeGenerated(
      openapi.RegisterResponse.serializer,
      json,
      'RegisterResponse',
    );
    return RegisterResponse(
      ok: parsed.ok,
      quota: parsed.quota == null
          ? null
          : RecordQuota.fromOpenApi(parsed.quota!),
    );
  }
}

class CleanupRequest {
  const CleanupRequest({required this.transcript, required this.language});

  final String transcript;
  final String language;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'transcript': transcript, 'language': language};
  }
}

class CleanupResponse {
  const CleanupResponse({
    required this.cleanedText,
    required this.wasTruncated,
    this.quota,
  });

  final String cleanedText;
  final bool wasTruncated;
  final RecordQuota? quota;

  factory CleanupResponse.fromJson(Map<String, dynamic> json) {
    final parsed = _deserializeGenerated(
      openapi.CleanupResponse.serializer,
      json,
      'CleanupResponse',
    );
    return CleanupResponse(
      cleanedText: parsed.cleanedText,
      wasTruncated: parsed.wasTruncated,
      quota: parsed.quota == null
          ? null
          : RecordQuota.fromOpenApi(parsed.quota!),
    );
  }
}

class TagRequest {
  const TagRequest({required this.text, required this.tags});

  final String text;
  final List<String> tags;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'text': text, 'tags': tags};
  }
}

class TagProbabilityItem {
  const TagProbabilityItem({required this.tag, required this.probability});

  final String tag;
  final double probability;
}

class TagResponse {
  const TagResponse({required this.tags});

  final List<TagProbabilityItem> tags;

  factory TagResponse.fromJson(Map<String, dynamic> json) {
    final parsed = _deserializeGenerated<openapi.TagResponse>(
      openapi.TagResponse.serializer,
      json,
      'TagResponse',
    );
    return TagResponse(
      tags: parsed.tags
          .map(
            (item) => TagProbabilityItem(
              tag: item.tag,
              probability: item.probability.toDouble(),
            ),
          )
          .toList(growable: false),
    );
  }
}

class TranscribeResponse {
  const TranscribeResponse({
    required this.transcript,
    required this.detectedLanguage,
    this.quota,
  });

  final String transcript;
  final String detectedLanguage;
  final RecordQuota? quota;

  factory TranscribeResponse.fromJson(Map<String, dynamic> json) {
    final parsed = _deserializeGenerated(
      openapi.TranscribeResponse.serializer,
      json,
      'TranscribeResponse',
    );
    return TranscribeResponse(
      transcript: parsed.transcript,
      detectedLanguage: parsed.detectedLanguage,
      quota: parsed.quota == null
          ? null
          : RecordQuota.fromOpenApi(parsed.quota!),
    );
  }
}

T _deserializeGenerated<T>(
  dynamic serializer,
  dynamic value,
  String description,
) {
  try {
    final parsed = openapi.standardSerializers.deserializeWith<T>(
      serializer,
      _asJsonMap(value, description),
    );
    if (parsed == null) {
      throw FormatException('Expected a valid $description payload.');
    }
    return parsed;
  } catch (error) {
    if (error is FormatException) {
      rethrow;
    }

    throw FormatException('Expected a valid $description payload.');
  }
}

dynamic _normalizeResponseData(dynamic data) {
  if (data is String && data.trim().isNotEmpty) {
    try {
      return jsonDecode(data);
    } on FormatException {
      return data;
    }
  }

  return data;
}

Map<String, dynamic> _asJsonMap(dynamic value, String fieldName) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }

  throw FormatException('Expected a JSON object for $fieldName.');
}
