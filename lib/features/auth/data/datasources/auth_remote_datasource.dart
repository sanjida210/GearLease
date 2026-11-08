import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/user_session_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserSessionModel> login(String email, String password);
  Future<Map<String, dynamic>> refreshToken(String refreshToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<UserSessionModel> login(String email, String password) async {
    try {
      final response = await apiClient.dio.post(
        '/api/v1/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return UserSessionModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      } else {
        throw ServerException(
          'Login failed with status code ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ServerException(
        e.message ?? 'Login failed due to network error',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await apiClient.dio.post(
        '/api/v1/auth/refresh',
        data: {
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return Map<String, dynamic>.from(response.data as Map);
      } else {
        throw ServerException(
          'Token refresh failed with status code ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ServerException(
        e.message ?? 'Token refresh failed due to network error',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
