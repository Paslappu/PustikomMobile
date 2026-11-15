import 'package:flutter/material.dart';
import 'package:qrscan/theme/app_colors.dart';

/// Design tokens (spacing, radii, status colours) exposed as a [ThemeExtension].
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    this.spaceXs = 4,
    this.spaceSm = 8,
    this.spaceMd = 16,
    this.spaceLg = 24,
    this.spaceXl = 32,
    this.radiusSm = 8,
    this.radiusMd = 12,
    this.radiusLg = 16,
    this.radiusXl = 24,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.info,
    required this.infoContainer,
    required this.mapDotPalette,
  });

  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;

  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;

  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color danger;
  final Color dangerContainer;
  final Color info;
  final Color infoContainer;

  final List<Color> mapDotPalette;

  static const AppTokens light = AppTokens(
    success: AppColors.success,
    successContainer: AppColors.successContainer,
    warning: AppColors.warning,
    warningContainer: AppColors.warningContainer,
    danger: AppColors.danger,
    dangerContainer: AppColors.dangerContainer,
    info: AppColors.info,
    infoContainer: AppColors.infoContainer,
    mapDotPalette: [
      Color(0xFF1E5AA8),
      Color(0xFF16704A),
      Color(0xFFF28C28),
      Color(0xFF00796B),
      Color(0xFFC2185B),
      Color(0xFF6D4C41),
    ],
  );

  @override
  AppTokens copyWith({
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? info,
    Color? infoContainer,
    List<Color>? mapDotPalette,
  }) {
    return AppTokens(
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      mapDotPalette: mapDotPalette ?? this.mapDotPalette,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    final first = t < 0.5;
    return AppTokens(
      spaceXs: first ? spaceXs : other.spaceXs,
      spaceSm: first ? spaceSm : other.spaceSm,
      spaceMd: first ? spaceMd : other.spaceMd,
      spaceLg: first ? spaceLg : other.spaceLg,
      spaceXl: first ? spaceXl : other.spaceXl,
      radiusSm: first ? radiusSm : other.radiusSm,
      radiusMd: first ? radiusMd : other.radiusMd,
      radiusLg: first ? radiusLg : other.radiusLg,
      radiusXl: first ? radiusXl : other.radiusXl,
      success: mix(success, other.success),
      successContainer: mix(successContainer, other.successContainer),
      warning: mix(warning, other.warning),
      warningContainer: mix(warningContainer, other.warningContainer),
      danger: mix(danger, other.danger),
      dangerContainer: mix(dangerContainer, other.dangerContainer),
      info: mix(info, other.info),
      infoContainer: mix(infoContainer, other.infoContainer),
      mapDotPalette: first ? mapDotPalette : other.mapDotPalette,
    );
  }
}

extension AppThemeX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
