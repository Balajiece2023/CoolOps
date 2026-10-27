import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ApiClient {
  late final Dio dio;

  ApiClient({String? baseUrl}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? AppConstants.defaultApiUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final customUrl = prefs.getString(AppConstants.keyCustomApiUrl);
          if (customUrl != null && customUrl.isNotEmpty) {
            options.baseUrl = customUrl;
          }

          final token = prefs.getString(AppConstants.keyAccessToken);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // If request is specifically to login or refresh, do not clear storage on error
          final path = error.requestOptions.path;
          if (error.response?.statusCode == 401 && !path.contains('/auth/login')) {
            final prefs = await SharedPreferences.getInstance();
            final refreshToken = prefs.getString(AppConstants.keyRefreshToken);

            // Attempt seamless token refresh if available
            if (refreshToken != null && refreshToken.isNotEmpty && !path.contains('/auth/refresh')) {
              try {
                final refreshDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
                final res = await refreshDio.post('/auth/refresh', data: {'refreshToken': refreshToken});
                final newAccessToken = res.data['data']['accessToken'];
                await prefs.setString(AppConstants.keyAccessToken, newAccessToken);

                // Retry original request with new token
                final reqOptions = error.requestOptions;
                reqOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                final clonedResponse = await dio.fetch(reqOptions);
                return handler.resolve(clonedResponse);
              } catch (_) {
                // If refresh fails, clear tokens
                await prefs.remove(AppConstants.keyAccessToken);
                await prefs.remove(AppConstants.keyRefreshToken);
              }
            } else {
              await prefs.remove(AppConstants.keyAccessToken);
              await prefs.remove(AppConstants.keyRefreshToken);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Categorizes and extracts clean error message distinguishing Server, DB, and Input issues
  static String formatErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return '🔌 SERVER CONNECTION ERROR: Unable to reach the server. Please check if the backend is running.';
      }

      final statusCode = error.response?.statusCode;
      final data = error.response?.data;

      // Check if backend returned structured error
      if (data is Map && data['error'] != null) {
        final err = data['error'];
        final code = err['code'] ?? '';
        final message = err['message'] ?? 'Unknown error';

        if (statusCode == 400) {
          if (err['details'] != null && err['details'] is List) {
            final details = (err['details'] as List).map((d) => '${d['field']}: ${d['message']}').join(', ');
            return '📝 INPUT ERROR: $message ($details)';
          }
          return '📝 INPUT ERROR: $message';
        }

        if (statusCode == 401 || statusCode == 403) {
          return '🔒 AUTHENTICATION ERROR: $message';
        }

        if (statusCode == 500 || statusCode == 503) {
          if (message.toString().toLowerCase().contains('database') ||
              message.toString().toLowerCase().contains('prisma')) {
            return '🗄️ DATABASE ERROR: $message';
          }
          return '⚙️ SERVER ERROR: $message';
        }

        return '⚠️ ERROR ($code): $message';
      }

      if (statusCode != null) {
        if (statusCode >= 500) return '⚙️ SERVER ERROR ($statusCode): Internal failure occurred.';
        if (statusCode == 400) return '📝 INPUT ERROR (400): Bad request parameters.';
        if (statusCode == 404) return '🔍 NOT FOUND (404): Requested record or endpoint does not exist.';
      }
    }

    return error.toString();
  }
}
