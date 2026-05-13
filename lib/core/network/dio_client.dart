import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

class DioClient {
  static Dio create() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (AppConstants.apiKey.isNotEmpty) {
      headers['x-api-key'] = AppConstants.apiKey;
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(
          milliseconds: AppConstants.connectTimeout,
        ),
        receiveTimeout: const Duration(
          milliseconds: AppConstants.receiveTimeout,
        ),
        headers: headers,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          // Propagate with a readable message
          handler.next(e);
        },
      ),
    );

    return dio;
  }
}
