import 'package:dio/dio.dart';

import '../models/open_meteo_current.dart';

/// Cliente HTTP para [Open-Meteo](https://open-meteo.com/en/docs) (sin API key).
class OpenMeteoApi {
  OpenMeteoApi._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.open-meteo.com/v1',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  static Future<OpenMeteoCurrent> fetchCurrent({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/forecast',
      queryParameters: <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'current': 'temperature_2m,weather_code',
        'timezone': 'auto',
      },
    );
    final data = response.data;
    if (data == null) {
      throw OpenMeteoException('Respuesta vacía');
    }
    final cur = data['current'] as Map<String, dynamic>?;
    if (cur == null) {
      throw OpenMeteoException('Sin bloque "current"');
    }
    final temp = cur['temperature_2m'];
    final code = cur['weather_code'];
    if (temp is! num || code is! num) {
      throw OpenMeteoException('Datos de temperatura o código inválidos');
    }
    return OpenMeteoCurrent(
      temperatureC: temp.toDouble(),
      weatherCode: code.round(),
    );
  }
}

class OpenMeteoException implements Exception {
  OpenMeteoException(this.message);
  final String message;

  @override
  String toString() => message;
}
