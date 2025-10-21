import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

// General failures
class ServerFailure extends Failure {
  const ServerFailure(String message, {String? code}) : super(message, code: code);
}

class CacheFailure extends Failure {
  const CacheFailure(String message, {String? code}) : super(message, code: code);
}

class NetworkFailure extends Failure {
  const NetworkFailure(String message, {String? code}) : super(message, code: code);
}

class ValidationFailure extends Failure {
  const ValidationFailure(String message, {String? code}) : super(message, code: code);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(String message, {String? code}) : super(message, code: code);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(String message, {String? code}) : super(message, code: code);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(String message, {String? code}) : super(message, code: code);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure(String message, {String? code}) : super(message, code: code);
}

// Helper function to convert exceptions to failures
Failure mapExceptionToFailure(dynamic e, {String? customMessage}) {
  if (e is Failure) return e;
  
  final message = customMessage ?? e.toString();
  
  if (e is FormatException) {
    return ValidationFailure(message);
  } else if (e is http.ClientException || e.toString().contains('TimeoutException')) {
    return const TimeoutFailure('انتهت مهلة الاتصال بالخادم');
  } else if (e.toString().contains('401') || e.toString().toLowerCase().contains('unauthorized')) {
    return const UnauthorizedFailure('غير مصرح بالوصول');
  } else if (e.toString().contains('404') || e.toString().toLowerCase().contains('not found')) {
    return const NotFoundFailure('لم يتم العثور على المورد المطلوب');
  } else if (e.toString().toLowerCase().contains('database') || 
             e.toString().toLowerCase().contains('sql')) {
    return DatabaseFailure('خطأ في قاعدة البيانات: ${e.toString()}');
  }
  
  return ServerFailure(message);
}
