import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../core/theme/app_theme.dart';

/// Loading reutilizable de la app. Usa `inkDrop` de loading_animation_widget
/// para un spinner más vivo que el `CircularProgressIndicator` por defecto.
///
/// El color se autodetecta del `Theme` salvo que se le pase explícito (útil en
/// pantallas con paleta custom como CineHax).
class AppLoading extends StatelessWidget {
  final Color? color;
  final double size;

  const AppLoading({super.key, this.color, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LoadingAnimationWidget.inkDrop(
        color: color ?? AppColors.accent2,
        size: size,
      ),
    );
  }
}
