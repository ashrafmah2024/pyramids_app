import 'package:flutter/foundation.dart';
import 'package:pyramids/features/users/domain/entities/user.dart';
import 'package:pyramids/features/users/domain/repositories/user_repository.dart';
import 'package:pyramids/features/users/domain/entities/user_status.dart';

class UserProvider with ChangeNotifier {
  final UserRepository _userRepository;
  
  // State
  bool _isLoading = false;
  String? _error;
  List<User> _users = [];
  User? _selectedUser;
  
  // Clear all users (used on logout)
  void clearUsers() {
    _users = [];
    _selectedUser = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<User> get users => _users;
  User? get selectedUser => _selectedUser;

  UserProvider({required UserRepository userRepository}) 
      : _userRepository = userRepository;

  // Clear error message
  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  // Set error message
  void _setError(String message) {
    _error = message;
    _isLoading = false;
    notifyListeners();
  }

  // Load all users
  Future<void> loadUsers() async {
    _isLoading = true;
    _clearError();
    notifyListeners();

    final result = await _userRepository.getUsers();
    
    result.fold(
      (failure) => _setError(failure.toString()),
      (users) {
        _users = users;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Get user by ID
  Future<void> getUserById(String id) async {
    _isLoading = true;
    _clearError();
    notifyListeners();

    final result = await _userRepository.getUser(id);
    
    result.fold(
      (failure) => _setError(failure.toString()),
      (user) {
        _selectedUser = user;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Create new user
  Future<bool> createUser(User user) async {
    _isLoading = true;
    _clearError();
    notifyListeners();

    final result = await _userRepository.createUser(user);
    
    return result.fold(
      (failure) {
        _setError(failure.toString());
        return false;
      },
      (createdUser) {
        _users.insert(0, createdUser);
        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  // Update existing user
  Future<bool> updateUser(User user) async {
    _isLoading = true;
    _clearError();
    notifyListeners();

    final result = await _userRepository.updateUser(user);
    
    return result.fold(
      (failure) {
        _setError(failure.toString());
        return false;
      },
      (updatedUser) {
        final index = _users.indexWhere((u) => u.id == updatedUser.id);
        if (index != -1) {
          _users[index] = updatedUser;
          if (_selectedUser?.id == updatedUser.id) {
            _selectedUser = updatedUser;
          }
          _isLoading = false;
          notifyListeners();
          // إعادة جلب للتأكد من تزامن القائمة مع القيم النهائية من قاعدة البيانات
          // (يفيد عند تغيّر قيم بسبب تريغرات أو سياسات RLS)
          loadUsers();
          return true;
        }
        _setError('User not found in the list');
        return false;
      },
    );
  }

  // Delete user
  Future<bool> deleteUser(String id) async {
    _isLoading = true;
    _clearError();
    notifyListeners();

    final result = await _userRepository.deleteUser(id);
    
    return result.fold(
      (failure) {
        _setError(failure.toString());
        return false;
      },
      (_) {
        _users.removeWhere((user) => user.id == id);
        if (_selectedUser?.id == id) {
          _selectedUser = null;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  // Update user status
  Future<bool> updateUserStatus({
    required String userId,
    required UserStatus status,
  }) async {
    _isLoading = true;
    _clearError();
    notifyListeners();

    final result = await _userRepository.updateUserStatus(
      userId: userId,
      status: status,
    );
    
    return result.fold(
      (failure) {
        _setError(failure.toString());
        return false;
      },
      (updatedUser) {
        final index = _users.indexWhere((u) => u.id == updatedUser.id);
        if (index != -1) {
          _users[index] = updatedUser;
          if (_selectedUser?.id == updatedUser.id) {
            _selectedUser = updatedUser;
          }
          _isLoading = false;
          notifyListeners();
          // إعادة جلب للتأكد من تزامن القائمة مع القيم النهائية من قاعدة البيانات
          loadUsers();
          return true;
        }
        _setError('User not found in the list');
        return false;
      },
    );
  }

  // Change user password (admin/manager or self)
  Future<bool> changeUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    _isLoading = true;
    _clearError();
    notifyListeners();

    final result = await _userRepository.changeUserPassword(
      userId: userId,
      newPassword: newPassword,
    );

    return result.fold(
      (failure) {
        _setError(failure.toString());
        return false;
      },
      (_) {
        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  // Clear selected user
  void clearSelectedUser() {
    _selectedUser = null;
    _clearError();
    notifyListeners();
  }
}
