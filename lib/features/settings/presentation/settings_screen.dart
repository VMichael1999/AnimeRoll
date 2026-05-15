import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../data/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeRevision = ref.watch(accentColorIndexProvider);
    final activeProvider = ref.watch(providerPrefProvider);
    final preferredServer = ref.watch(preferredPlaybackServerProvider);
    return Scaffold(
      key: ValueKey('settings-$themeRevision'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Ajustes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            const _SettingsAvatar(),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Proveedor',
              children: [
                _PickerRow(
                  icon: Icons.language_rounded,
                  label: 'Proveedor activo',
                  value: ref.watch(providerPrefProvider).split('.').first,
                  onTap: () => _showProviderPicker(context, ref),
                ),
                _SwitchRow(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Fallback automático',
                  subtitle: 'Cambia si el servidor falla',
                  value: ref.watch(fallbackPrefProvider),
                  onChanged: (v) =>
                      ref.read(fallbackPrefProvider.notifier).set(v),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Reproducción',
              children: [
                _PickerRow(
                  icon: Icons.dns_rounded,
                  label: 'Servidor preferido',
                  value: activeProvider == 'hentaila.com'
                      ? 'VIP'
                      : preferredServer.isEmpty
                      ? 'Auto'
                      : preferredServer,
                  onTap: () => ref
                      .read(preferredPlaybackServerProvider.notifier)
                      .set(''),
                ),
                _PickerRow(
                  icon: Icons.high_quality_rounded,
                  label: 'Calidad por defecto',
                  value: ref.watch(qualityPrefProvider),
                  onTap: () => _showQualityPicker(context, ref),
                ),
                _PickerRow(
                  icon: Icons.subtitles_rounded,
                  label: 'Variante preferida',
                  value: ref.watch(variantPrefProvider),
                  onTap: () => _showVariantPicker(context, ref),
                ),
                _SwitchRow(
                  icon: Icons.skip_next_rounded,
                  label: 'Reproducción automática',
                  subtitle: 'Siguiente episodio',
                  value: ref.watch(autoplayPrefProvider),
                  onChanged: (v) =>
                      ref.read(autoplayPrefProvider.notifier).set(v),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Descargas',
              children: [
                _SwitchRow(
                  icon: Icons.wifi_rounded,
                  label: 'Solo WiFi',
                  subtitle: 'No usar datos móviles',
                  value: ref.watch(wifiOnlyPrefProvider),
                  onChanged: (v) =>
                      ref.read(wifiOnlyPrefProvider.notifier).set(v),
                ),
                _PickerRow(
                  icon: Icons.bolt_rounded,
                  label: 'Descargas simultáneas',
                  value: '${ref.watch(simultaneousDownloadsProvider)}',
                  onTap: () => _showSimultaneousPicker(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'AI Recap',
              children: [
                _PickerRow(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Detalle del resumen',
                  value: switch (ref.watch(recapDetailPrefProvider)) {
                    'short' => 'Corto',
                    'long' => 'Largo',
                    _ => 'Medio',
                  },
                  onTap: () => _showRecapDetailPicker(context, ref),
                ),
                _PickerRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Mostrar recap tras',
                  value: '${ref.watch(recapDaysThresholdPrefProvider)} días',
                  onTap: () => _showRecapDaysPicker(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Apariencia',
              children: [_AppearancePanel()],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'App',
              children: [
                _SwitchRow(
                  icon: Icons.dark_mode_rounded,
                  label: 'Tema oscuro',
                  value: ref.watch(darkThemePrefProvider),
                  onChanged: (v) =>
                      ref.read(darkThemePrefProvider.notifier).set(v),
                ),
                _SwitchRow(
                  icon: Icons.bug_report_rounded,
                  label: 'Modo debug',
                  subtitle: 'DEBUG_DOWNLOAD',
                  value: ref.watch(debugDownloadPrefProvider),
                  onChanged: (v) =>
                      ref.read(debugDownloadPrefProvider.notifier).set(v),
                ),
                _InfoRow(
                  icon: Icons.info_outline_rounded,
                  label: 'Versión',
                  value: '1.0.0',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showProviderPicker(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.read(availableProvidersProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Seleccionar proveedor',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ...providersAsync
              .maybeWhen(
                data: (providers) => providers,
                orElse: () => const <String>[],
              )
              .map(
                (p) => ListTile(
                  title: Text(p, style: TextStyle(fontSize: 13)),
                  trailing: ref.watch(providerPrefProvider) == p
                      ? Icon(Icons.check_rounded, color: AppColors.accent2)
                      : null,
                  onTap: () {
                    ref.read(providerPrefProvider.notifier).set(p);
                    Navigator.pop(context);
                  },
                ),
              ),
          if (providersAsync.isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showQualityPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Calidad por defecto',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ...AppConstants.qualities.map(
            (q) => ListTile(
              title: Text(q, style: TextStyle(fontSize: 13)),
              trailing: ref.watch(qualityPrefProvider) == q
                  ? Icon(Icons.check_rounded, color: AppColors.accent2)
                  : null,
              onTap: () {
                ref.read(qualityPrefProvider.notifier).set(q);
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showVariantPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Variante preferida',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ...AppConstants.variants.map(
            (v) => ListTile(
              title: Text(v, style: TextStyle(fontSize: 13)),
              trailing: ref.watch(variantPrefProvider) == v
                  ? Icon(Icons.check_rounded, color: AppColors.accent2)
                  : null,
              onTap: () {
                ref.read(variantPrefProvider.notifier).set(v);
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showRecapDetailPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Detalle del recap',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final entry in [
            ('short', 'Corto', '1 frase'),
            ('medium', 'Medio', '2-3 frases'),
            ('long', 'Largo', '4-5 frases detalladas'),
          ])
            ListTile(
              title: Text(entry.$2, style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                entry.$3,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: ref.watch(recapDetailPrefProvider) == entry.$1
                  ? Icon(Icons.check_rounded, color: AppColors.accent2)
                  : null,
              onTap: () {
                ref.read(recapDetailPrefProvider.notifier).set(entry.$1);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showRecapDaysPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Mostrar recap si llevas X días sin ver',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final days in [1, 3, 5, 7, 14, 30])
            ListTile(
              title: Text('$days días', style: const TextStyle(fontSize: 13)),
              trailing: ref.watch(recapDaysThresholdPrefProvider) == days
                  ? Icon(Icons.check_rounded, color: AppColors.accent2)
                  : null,
              onTap: () {
                ref.read(recapDaysThresholdPrefProvider.notifier).set(days);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showSimultaneousPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Descargas simultáneas',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ...[1, 2, 3, 4, 5].map(
            (value) => ListTile(
              title: Text('$value', style: TextStyle(fontSize: 13)),
              trailing: ref.watch(simultaneousDownloadsProvider) == value
                  ? Icon(Icons.check_rounded, color: AppColors.accent2)
                  : null,
              onTap: () {
                ref.read(simultaneousDownloadsProvider.notifier).set(value);
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Reusable rows ─────────────────────────────────────────────────────────────

class _SettingsAvatar extends StatelessWidget {
  const _SettingsAvatar();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/profile'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accent,
              child: Text(
                'M',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Michael',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Ver perfil y estadisticas',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 6),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: children.indexed.map((e) {
              final (i, child) = e;
              return Column(
                children: [
                  child,
                  if (i < children.length - 1)
                    Divider(height: 1, indent: 50, color: AppColors.border),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accent2,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              value,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AppearanceTitle('Tema de color'),
          SizedBox(height: 10),
          _ThemePresetGrid(),
          SizedBox(height: 16),
          _AppearanceTitle('Acento personalizado'),
          SizedBox(height: 10),
          _AccentSwatches(),
          SizedBox(height: 16),
          _AppearanceTitle('Vista del catálogo'),
          SizedBox(height: 10),
          _CatalogLayoutSelector(),
          SizedBox(height: 16),
          _AppearanceTitle('Ícono de app'),
          SizedBox(height: 10),
          _AppIconSelector(),
        ],
      ),
    );
  }
}

class _AppearanceTitle extends StatelessWidget {
  final String text;

  const _AppearanceTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    );
  }
}

class _ThemePresetGrid extends ConsumerWidget {
  const _ThemePresetGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(accentColorIndexProvider);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.48,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: AppTheme.accentPresets.take(4).indexed.map((entry) {
        final (i, preset) = entry;
        final isSelected = i == selected;
        return GestureDetector(
          onTap: () => ref.read(accentColorIndexProvider.notifier).set(i),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: preset.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? preset.secondary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PreviewLine(width: 44, color: preset.secondary),
                      const SizedBox(height: 5),
                      _PreviewLine(width: 72, color: preset.primary),
                      const SizedBox(height: 5),
                      _PreviewLine(width: 55, color: AppColors.border),
                    ],
                  ),
                ),
                if (isSelected)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: preset.secondary,
                      child: Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Text(
                    i == 0 ? '${preset.name} (actual)' : preset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  final double width;
  final Color color;

  const _PreviewLine({required this.width, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _AccentSwatches extends ConsumerWidget {
  const _AccentSwatches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(accentColorIndexProvider);
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: AppTheme.accentPresets.indexed.map((entry) {
        final (i, preset) = entry;
        final isSelected = i == selected;
        return GestureDetector(
          onTap: () => ref.read(accentColorIndexProvider.notifier).set(i),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: preset.secondary,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: isSelected
                ? Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _CatalogLayoutSelector extends ConsumerWidget {
  const _CatalogLayoutSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(catalogLayoutProvider);
    return Row(
      children: [
        Expanded(
          child: _SegmentCard(
            icon: Icons.grid_view_rounded,
            label: 'Cuadrícula',
            active: selected == 'grid',
            onTap: () => ref.read(catalogLayoutProvider.notifier).set('grid'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SegmentCard(
            icon: Icons.view_list_rounded,
            label: 'Lista',
            active: selected == 'list',
            onTap: () => ref.read(catalogLayoutProvider.notifier).set('list'),
          ),
        ),
      ],
    );
  }
}

class _SegmentCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SegmentCard({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.16)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.accent2 : AppColors.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? AppColors.accent2 : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.accent2 : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppIconSelector extends ConsumerWidget {
  const _AppIconSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appIconStyleProvider);
    final icons = [
      ('violeta', 'assets/app_icons/violeta.png'),
      ('oceano', 'assets/app_icons/oceano.png'),
      ('carmesi', 'assets/app_icons/carmesi.png'),
      ('esmeralda', 'assets/app_icons/esmeralda.png'),
    ];
    return Row(
      children: icons.map((item) {
        final (id, asset) = item;
        final active = selected == id;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => ref.read(appIconStyleProvider.notifier).set(id),
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? AppColors.accent2 : AppColors.border,
                    width: active ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(asset, width: 42, height: 42),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
