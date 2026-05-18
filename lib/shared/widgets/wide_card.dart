import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/anime_model.dart';
import 'app_network_image.dart';

class WideCard extends StatelessWidget {
  final AnimeModel anime;
  final String? subtitle;
  final VoidCallback? onTap;

  const WideCard({super.key, required this.anime, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 200,
          height: 110,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(
                url: anime.cover,
                width: 200,
                height: 110,
                color: Colors.black.withValues(alpha: 0.4),
                colorBlendMode: BlendMode.darken,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anime.title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
