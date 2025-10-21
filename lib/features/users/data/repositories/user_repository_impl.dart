import 'package:dartz/dartz.dart';
import 'package:pyramids/features/users/data/datasources/user_remote_data_source.dart';
import 'package:pyramids/features/users/domain/entities/user.dart';
import 'package:pyramids/features/users/domain/entities/user_status.dart';
import 'package:pyramids/features/users/domain/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remoteDataSource;

  UserRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Exception, List<User>>> getUsers() async {
    try {
      final users = await remoteDataSource.getUsers();
      return Right(users);
    } catch (e) {
      return Left(Exception('Failed to get users: $e'));
    }
  }

  @override
  Future<Either<Exception, User>> getUser(String id) async {
    try {
      final user = await remoteDataSource.getUser(id);
      return Right(user);
    } catch (e) {
      return Left(Exception('Failed to get user: $e'));
    }
  }

  @override
  Future<Either<Exception, User>> createUser(User user) async {
    try {
      final createdUser = await remoteDataSource.createUser(user);
      return Right(createdUser);
    } catch (e) {
      return Left(Exception('Failed to create user: $e'));
    }
  }

  @override
  Future<Either<Exception, User>> updateUser(User user) async {
    try {
      final updatedUser = await remoteDataSource.updateUser(user);
      return Right(updatedUser);
    } catch (e) {
      return Left(Exception('Failed to update user: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> deleteUser(String id) async {
    try {
      await remoteDataSource.deleteUser(id);
      return const Right(null);
    } catch (e) {
      return Left(Exception('Failed to delete user: $e'));
    }
  }

  @override
  Future<Either<Exception, User>> updateUserStatus({
    required String userId,
    required UserStatus status,
  }) async {
    try {
      final updatedUser = await remoteDataSource.updateUserStatus(
        userId: userId,
        status: status,
      );
      return Right(updatedUser);
    } catch (e) {
      return Left(Exception('Failed to update user status: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> changeUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      await remoteDataSource.changeUserPassword(
        userId: userId,
        newPassword: newPassword,
      );
      return const Right(null);
    } catch (e) {
      return Left(Exception('Failed to change user password: $e'));
    }
  }
}
