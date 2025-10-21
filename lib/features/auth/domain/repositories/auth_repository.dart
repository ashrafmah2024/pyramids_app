import 'package:pyramids/features/auth/domain/models/user_model.dart';

abstract class AuthRepository {
  // Check if user is logged in
  Future<bool> isSignedIn();
  
  // Get current user
  Future<UserModel?> getCurrentUser();
  
  // Sign in with email and password
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  
  // Sign up with email and password
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  });
  
  // Sign out
  Future<void> signOut();
  
  // Reset password
  Future<void> resetPassword(String email);
  
  // Update user profile
  Future<UserModel> updateProfile({
    required String userId,
    String? fullName,
    String? phoneNumber,
    String? profileImageUrl,
  });
  
  // Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  
  // Check if email is verified
  Future<bool> isEmailVerified();
  
  // Send email verification
  Future<void> sendEmailVerification();
  
  // Delete account
  Future<void> deleteAccount(String password);
}
