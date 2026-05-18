// Skeleton screens reutilizables construidos sobre `fade_shimmer`. Cada uno
// imita el shape real del contenido que está cargando para que el usuario
// perciba la app más rápida que con un spinner centrado.
//
// Convención: todos exponen `dark` por default. Si en algún momento agregamos
// tema light hay que pasar `theme: FadeTheme.light`.
import 'package:fade_shimmer/fade_shimmer.dart';
import 'package:flutter/material.dart';

// ── Building blocks ──────────────────────────────────────────────────────────

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final FadeTheme theme;
  final int millisecondsDelay;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
    this.theme = FadeTheme.dark,
    this.millisecondsDelay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return FadeShimmer(
      width: width ?? double.infinity,
      height: height ?? 16,
      radius: radius,
      fadeTheme: theme,
      millisecondsDelay: millisecondsDelay,
    );
  }
}

class ShimmerCircle extends StatelessWidget {
  final double size;
  final FadeTheme theme;
  final int millisecondsDelay;

  const ShimmerCircle({
    super.key,
    required this.size,
    this.theme = FadeTheme.dark,
    this.millisecondsDelay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return FadeShimmer.round(
      size: size,
      fadeTheme: theme,
      millisecondsDelay: millisecondsDelay,
    );
  }
}

// ── Cards / placeholders ──────────────────────────────────────────────────────

/// Placeholder de un poster 2:3 con título debajo. Usado en filas
/// horizontales del home (CineHax, hentaila, etc.) y grids.
class PosterCardSkeleton extends StatelessWidget {
  final double width;
  final int delay;

  const PosterCardSkeleton({
    super.key,
    this.width = 110,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: ShimmerBox(
                radius: 10,
                millisecondsDelay: delay,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ShimmerBox(
            height: 10,
            width: width * 0.9,
            millisecondsDelay: delay + 50,
          ),
          const SizedBox(height: 4),
          ShimmerBox(
            height: 8,
            width: width * 0.6,
            millisecondsDelay: delay + 100,
          ),
        ],
      ),
    );
  }
}

/// Fila horizontal de posters skeleton con header (título + "Ver todo").
class PosterRowSkeleton extends StatelessWidget {
  final int count;
  final double posterWidth;
  final EdgeInsets padding;
  final bool showHeader;
  final int delayOffset;

  const PosterRowSkeleton({
    super.key,
    this.count = 5,
    this.posterWidth = 110,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.showHeader = true,
    this.delayOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Padding(
              padding: padding.copyWith(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerBox(
                    width: 140,
                    height: 14,
                    millisecondsDelay: delayOffset,
                  ),
                  ShimmerBox(
                    width: 60,
                    height: 11,
                    millisecondsDelay: delayOffset + 50,
                  ),
                ],
              ),
            ),
          SizedBox(
            height: posterWidth * 1.6,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: padding,
              itemCount: count,
              separatorBuilder: (context, idx) => const SizedBox(width: 10),
              itemBuilder: (context, i) => PosterCardSkeleton(
                width: posterWidth,
                delay: delayOffset + i * 80,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero/banner skeleton (proporciones 16:10) con chip, título y botón.
class HeroSkeleton extends StatelessWidget {
  final EdgeInsets margin;
  final double aspectRatio;

  const HeroSkeleton({
    super.key,
    this.margin = const EdgeInsets.fromLTRB(16, 14, 16, 20),
    this.aspectRatio = 16 / 10,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: const ShimmerBox(radius: 16),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(width: 80, height: 14, radius: 6),
                  SizedBox(height: 10),
                  ShimmerBox(width: 220, height: 22, radius: 6),
                  SizedBox(height: 8),
                  ShimmerBox(width: 130, height: 12, radius: 4),
                  SizedBox(height: 14),
                  ShimmerBox(width: 110, height: 32, radius: 999),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid 3-col de posters skeleton (para pantallas "Ver todo" y catálogo).
class PosterGridSkeleton extends StatelessWidget {
  final int count;
  final int crossAxisCount;
  final EdgeInsets padding;

  const PosterGridSkeleton({
    super.key,
    this.count = 9,
    this.crossAxisCount = 3,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
          childAspectRatio: 0.56,
        ),
        itemCount: count,
        itemBuilder: (context, i) => PosterCardSkeleton(delay: i * 60),
      ),
    );
  }
}

/// Skeleton del detalle de un título (cover + título + tags + sinopsis + CTA).
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top backdrop
          const ShimmerBox(height: 160, radius: 14),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: const ShimmerBox(width: 70, height: 98, radius: 10),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: double.infinity, height: 18, radius: 6),
                    SizedBox(height: 6),
                    ShimmerBox(width: 140, height: 11, radius: 4),
                    SizedBox(height: 12),
                    ShimmerBox(width: 180, height: 22, radius: 6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const ShimmerBox(width: double.infinity, height: 10, radius: 4),
          const SizedBox(height: 6),
          const ShimmerBox(width: double.infinity, height: 10, radius: 4),
          const SizedBox(height: 6),
          const ShimmerBox(width: 220, height: 10, radius: 4),
          const SizedBox(height: 18),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(
              5,
              (i) => ShimmerBox(
                width: 70.0 + (i % 3) * 18,
                height: 24,
                radius: 999,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              Expanded(child: ShimmerBox(height: 42, radius: 10)),
              SizedBox(width: 8),
              ShimmerBox(width: 42, height: 42, radius: 10),
            ],
          ),
          const SizedBox(height: 24),
          // Episodes list
          ...List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ShimmerBox(
                      width: 92,
                      height: 52,
                      radius: 8,
                      millisecondsDelay: i * 80,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(
                          width: double.infinity,
                          height: 12,
                          radius: 4,
                          millisecondsDelay: i * 80 + 50,
                        ),
                        const SizedBox(height: 6),
                        ShimmerBox(
                          width: 90,
                          height: 10,
                          radius: 4,
                          millisecondsDelay: i * 80 + 100,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton completo del home tipo CineHax (hero + N filas de posters).
class HomeFeedSkeleton extends StatelessWidget {
  final int rowCount;

  const HomeFeedSkeleton({super.key, this.rowCount = 4});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 14),
      children: [
        const HeroSkeleton(),
        for (int i = 0; i < rowCount; i++)
          PosterRowSkeleton(delayOffset: i * 100),
      ],
    );
  }
}

/// Skeleton de lista vertical (para historial, descargas, búsqueda lista).
class ListRowSkeleton extends StatelessWidget {
  final int count;
  final double thumbWidth;
  final double thumbHeight;

  const ListRowSkeleton({
    super.key,
    this.count = 8,
    this.thumbWidth = 92,
    this.thumbHeight = 52,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: count,
      separatorBuilder: (context, idx) => const SizedBox(height: 10),
      itemBuilder: (context, i) => Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ShimmerBox(
              width: thumbWidth,
              height: thumbHeight,
              radius: 8,
              millisecondsDelay: i * 80,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                  width: double.infinity,
                  height: 12,
                  radius: 4,
                  millisecondsDelay: i * 80 + 40,
                ),
                const SizedBox(height: 6),
                ShimmerBox(
                  width: 140,
                  height: 10,
                  radius: 4,
                  millisecondsDelay: i * 80 + 80,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
