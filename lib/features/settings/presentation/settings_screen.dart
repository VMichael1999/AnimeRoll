import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../data/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
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
                  value: ref.watch(preferredPlaybackServerProvider).isEmpty
                      ? 'Auto'
                      : ref.watch(preferredPlaybackServerProvider),
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
              'Seleccionar proveedor',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ...AppConstants.providers.map(
            (p) => ListTile(
              title: Text(p, style: const TextStyle(fontSize: 13)),
              trailing: ref.watch(providerPrefProvider) == p
                  ? const Icon(Icons.check_rounded, color: AppColors.accent2)
                  : null,
              onTap: () {
                ref.read(providerPrefProvider.notifier).set(p);
                Navigator.pop(context);
              },
            ),
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
      shape: const RoundedRectangleBorder(
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
              title: Text(q, style: const TextStyle(fontSize: 13)),
              trailing: ref.watch(qualityPrefProvider) == q
                  ? const Icon(Icons.check_rounded, color: AppColors.accent2)
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
      shape: const RoundedRectangleBorder(
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
              title: Text(v, style: const TextStyle(fontSize: 13)),
              trailing: ref.watch(variantPrefProvider) == v
                  ? const Icon(Icons.check_rounded, color: AppColors.accent2)
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

  void _showSimultaneousPicker(BuildContext context, WidgetRef ref) {
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
              'Descargas simultáneas',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ...[1, 2, 3, 4, 5].map(
            (value) => ListTile(
              title: Text('$value', style: const TextStyle(fontSize: 13)),
              trailing: ref.watch(simultaneousDownloadsProvider) == value
                  ? const Icon(Icons.check_rounded, color: AppColors.accent2)
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.accent,
            child: Text(
              'A',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AnimeRoll',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Tu anime, sin límites',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            style: const TextStyle(
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
                    const Divider(
                      height: 1,
                      indent: 50,
                      color: AppColors.border,
                    ),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
