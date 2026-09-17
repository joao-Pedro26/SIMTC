import 'package:dio/dio.dart';
import '../../../utils/api_constants.dart';
import '../../../utils/result.dart';

class ApiService {
  late final Dio _dio;

  ApiService({Dio? dio}) {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
            headers: {'Content-Type': 'application/json'},
          ),
        );
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  Future<Result<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic data)? parser,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      final data = parser != null ? parser(response.data) : response.data as T;
      return Success(data);
    } on DioException catch (e) {
      return Failure(e, e.message);
    } catch (e) {
      return Failure(Exception(e.toString()));
    }
  }

  Future<Result<T>> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic data)? parser,
  }) async {
    try {
      final response = await _dio.post(path, data: data);
      final resultData = parser != null ? parser(response.data) : response.data as T;
      return Success(resultData);
    } on DioException catch (e) {
      return Failure(e, e.message);
    } catch (e) {
      return Failure(Exception(e.toString()));
    }
  }
}
