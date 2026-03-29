import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/app_config.dart';
import '../models/query_response.dart';

/// Único punto de entrada HTTP para “hablar con el asistente”: `GET /api/v1/query`.
class AssistantApi {
  AssistantApi({required String baseUrl})
      : _base = baseUrl.replaceAll(RegExp(r'/$'), '') {
    _dio = Dio(
      BaseOptions(
        baseUrl: _base,
        connectTimeout: Duration(seconds: AppConfig.queryTimeoutSeconds),
        receiveTimeout: Duration(seconds: AppConfig.queryTimeoutSeconds),
        sendTimeout: Duration(seconds: AppConfig.queryTimeoutSeconds),
        validateStatus: (s) => s != null && s < 500,
      ),
    );
  }

  final String _base;
  late final Dio _dio;

  /// `message` se codifica en la query string (tildes, espacios).
  Future<QueryResponse> query(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('message no puede estar vacío');
    }
    final uri = Uri.parse('$_base/api/v1/query').replace(
      queryParameters: {'message': trimmed},
    );
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(uri);
      final code = response.statusCode ?? 0;
      if (code != 200) {
        throw AssistantApiException(
          'El servidor respondió con código $code',
          statusCode: code,
        );
      }
      final data = response.data;
      if (data == null) {
        throw const AssistantApiException('Respuesta vacía del servidor');
      }
      return QueryResponse.fromJson(data);
    } on DioException catch (e) {
      throw AssistantApiException(_dioErrorMessage(e), cause: e);
    }
  }

  /// `GET /health` — comprobación rápida de conectividad.
  Future<bool> health() async {
    final healthUri = Uri.parse('$_base/health');
    try {
      final response = await _dio.getUri<String>(
        healthUri,
        options: Options(
          receiveTimeout: Duration(seconds: AppConfig.healthTimeoutSeconds),
          connectTimeout: Duration(seconds: AppConfig.healthTimeoutSeconds),
          responseType: ResponseType.plain,
        ),
      );
      if (response.statusCode != 200) return false;
      final body = response.data?.trim() ?? '';
      if (body.isEmpty) return false;
      try {
        final map = jsonDecode(body) as Map<String, dynamic>;
        return map['status'] == 'ok';
      } catch (_) {
        return false;
      }
    } on DioException {
      return false;
    }
  }

  static String _dioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Tiempo de espera agotado. ¿Está el backend en marcha?';
      case DioExceptionType.connectionError:
        return 'No se pudo conectar. Revisa la URL y la red.';
      case DioExceptionType.badResponse:
        return 'Respuesta no válida (${e.response?.statusCode ?? "?"})';
      default:
        return e.message ?? 'Error de red desconocido';
    }
  }
}

class AssistantApiException implements Exception {
  const AssistantApiException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}
