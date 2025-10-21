import 'package:dartz/dartz.dart';
import 'package:pyramids/features/users/domain/entities/user.dart';
import 'package:pyramids/features/users/domain/entities/user_status.dart';

abstract class UserRepository {
  Future<Either<Exception, List<User>>> getUsers();
  Future<Either<Exception, User>> getUser(String id);
  Future<Either<Exception, User>> createUser(User user);
  Future<Either<Exception, User>> updateUser(User user);
  Future<Either<Exception, void>> deleteUser(String id);
  Future<Either<Exception, User>> updateUserStatus({
    required String userId,
    required UserStatus status,
  });
  Future<Either<Exception, void>> changeUserPassword({
    required String userId,
    required String newPassword,
  });
}
