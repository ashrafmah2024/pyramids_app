import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Private constructor to prevent instantiation
  AppTextStyles._();

  // Display text styles
  static const TextStyle displayLarge = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    letterSpacing: -0.25,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Headline text styles
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Title text styles
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // Body text styles
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Label text styles
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // Button text styles
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textOnPrimary,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textOnPrimary,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textOnPrimary,
  );

  // Custom text styles
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle inputLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle inputText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle hintText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );

  static const TextStyle errorText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.error,
  );

  static const TextStyle linkText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
    decoration: TextDecoration.underline,
  );

  // Status text styles
  static TextStyle statusActive = const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.active,
  );

  static TextStyle statusInactive = const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.inactive,
  );

  static TextStyle statusPending = const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.pending,
  );

  static TextStyle statusSuspended = const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.suspended,
  );

  // Business domain specific text styles
  static const TextStyle domainPlastics = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.plastics,
  );

  static const TextStyle domainStretchFilm = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.stretchFilm,
  );

  static const TextStyle domainBoxes = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.boxes,
  );

  static const TextStyle domainCarton = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.carton,
  );

  static const TextStyle domainStickers = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.stickers,
  );

  static const TextStyle domainSoliteep = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.soliteep,
  );
}
