import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/settings_provider.dart';

// Hardcoded VIP code for CineHax unlock. Format: 6 digits, displayed as
// XXX-XXX in the UI. Move to a remote-config / env if it ever needs to
// rotate without shipping a new build.
const _kCinehaxVipCode = '999999';

/// Shows the provider picker sheet, replacing the previous simple list.
/// Returns when the sheet is dismissed.
Future<void> showProviderPickerSheet({
  required BuildContext context,
  required WidgetRef ref,
  required List<String> providers,
  required bool isLoading,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _ProviderPickerSheet(
      providers: providers,
      isLoading: isLoading,
    ),
  );
}

class _ProviderPickerSheet extends ConsumerWidget {
  final List<String> providers;
  final bool isLoading;

  const _ProviderPickerSheet({
    required this.providers,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(providerPrefProvider);
    final vipUnlocked = ref.watch(cinehaxVipUnlockedProvider);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Proveedor activo',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: providers.length,
                itemBuilder: (context, index) {
                  final domain = providers[index];
                  final meta = _metaFor(domain);
                  final isActive = selected == domain;
                  final isCinehax = domain == 'cinehax.com';
                  final locked = isCinehax && !vipUnlocked;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ProviderRow(
                      meta: meta,
                      active: isActive,
                      locked: locked,
                      onTap: () => _onSelect(
                        context,
                        ref,
                        domain,
                        locked: locked,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: AppLoading(size: 32),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _onSelect(
    BuildContext context,
    WidgetRef ref,
    String domain, {
    required bool locked,
  }) async {
    if (locked) {
      final unlocked = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const _VipUnlockDialog(),
      );
      if (unlocked != true) return;
      if (!context.mounted) return;
    }
    ref.read(providerPrefProvider.notifier).set(domain);
    Navigator.of(context).pop();
  }

  static _ProviderMeta _metaFor(String domain) {
    return switch (domain) {
      'animeav1.com' => const _ProviderMeta(
          label: 'AnimeAV1',
          subtitle: 'Anime · SUB y DUB',
          initials: 'AV1',
          gradient: [Color(0xFF7C3AED), Color(0xFFA855F7)],
          textColor: Colors.white,
        ),
      'animeflv.net' => const _ProviderMeta(
          label: 'AnimeFLV',
          subtitle: 'Anime · catálogo amplio',
          initials: 'FLV',
          gradient: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
          textColor: Colors.white,
        ),
      'tioanime.com' => const _ProviderMeta(
          label: 'TioAnime',
          subtitle: 'Anime · clásicos',
          initials: 'TIO',
          gradient: [Color(0xFFF59E0B), Color(0xFFEAB308)],
          textColor: Colors.black,
        ),
      'jkanime.net' => const _ProviderMeta(
          label: 'JKAnime',
          subtitle: 'Anime · novedades',
          initials: 'JK',
          gradient: [Color(0xFF10B981), Color(0xFF059669)],
          textColor: Colors.white,
        ),
      'monoschinos2.net' => const _ProviderMeta(
          label: 'MonosChinos',
          subtitle: 'Anime · 13.000+ episodios',
          initials: '🐵',
          gradient: [Color(0xFFFBBF24), Color(0xFFEF4444)],
          textColor: Colors.white,
        ),
      'hentaila.com' => const _ProviderMeta(
          label: 'HentaiLA',
          subtitle: 'Adulto · 18+',
          initials: 'H',
          gradient: [Color(0xFFEC4899), Color(0xFF7C3AED)],
          textColor: Colors.white,
          italic: true,
        ),
      'hentaitk.net' => const _ProviderMeta(
          label: 'HentaiTK',
          subtitle: 'Adulto · 18+',
          initials: 'TK',
          gradient: [Color(0xFFEC4899), Color(0xFFEF4444)],
          textColor: Colors.white,
          italic: true,
        ),
      'cinehax.com' => const _ProviderMeta(
          label: 'CineHax',
          subtitle: 'Películas y series · Acceso premium',
          initials: 'CH',
          gradient: [Color(0xFF06101E), Color(0xFF2B8BFF)],
          textColor: Colors.white,
          isVip: true,
        ),
      _ => _ProviderMeta(
          label: domain.split('.').first,
          subtitle: domain,
          initials: domain.substring(0, 2).toUpperCase(),
          gradient: const [Color(0xFF4B5563), Color(0xFF6B7280)],
          textColor: Colors.white,
        ),
    };
  }
}

class _ProviderMeta {
  final String label;
  final String subtitle;
  final String initials;
  final List<Color> gradient;
  final Color textColor;
  final bool italic;
  final bool isVip;

  const _ProviderMeta({
    required this.label,
    required this.subtitle,
    required this.initials,
    required this.gradient,
    required this.textColor,
    this.italic = false,
    this.isVip = false,
  });
}

class _ProviderRow extends StatelessWidget {
  final _ProviderMeta meta;
  final bool active;
  final bool locked;
  final VoidCallback onTap;

  const _ProviderRow({
    required this.meta,
    required this.active,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: locked ? 0.88 : 1,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withValues(alpha: 0.08)
                : AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AppColors.accent2 : AppColors.border,
              width: active ? 1.3 : 1,
            ),
          ),
          child: Row(
            children: [
              _Avatar(meta: meta),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            meta.label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (meta.isVip) ...[
                          const SizedBox(width: 8),
                          const _VipBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta.subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _TrailingIndicator(active: active, locked: locked),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final _ProviderMeta meta;
  const _Avatar({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: meta.gradient,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        meta.initials,
        style: TextStyle(
          fontSize: meta.initials.length <= 2 ? 14 : 11,
          fontWeight: FontWeight.w900,
          color: meta.textColor,
          fontStyle: meta.italic ? FontStyle.italic : FontStyle.normal,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class _VipBadge extends StatelessWidget {
  const _VipBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB820), Color(0xFFF59E0B)],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.lock_rounded, size: 10, color: Color(0xFF1A0A05)),
          SizedBox(width: 3),
          Text(
            'VIP',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A0A05),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailingIndicator extends StatelessWidget {
  final bool active;
  final bool locked;

  const _TrailingIndicator({required this.active, required this.locked});

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 2),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.lock_rounded,
          size: 11,
          color: AppColors.textSecondary,
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? AppColors.accent : AppColors.border,
          width: 2,
        ),
      ),
      child: active
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
              ),
            )
          : null,
    );
  }
}

// ── VIP Unlock dialog ─────────────────────────────────────────────────────────

class _VipUnlockDialog extends ConsumerStatefulWidget {
  const _VipUnlockDialog();

  @override
  ConsumerState<_VipUnlockDialog> createState() => _VipUnlockDialogState();
}

class _VipUnlockDialogState extends ConsumerState<_VipUnlockDialog> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _attempt() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });

    // Tiny delay so the UI doesn't feel instant.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    if (_code == _kCinehaxVipCode) {
      await ref.read(cinehaxVipUnlockedProvider.notifier).set(true);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _checking = false;
      _error = 'Código incorrecto';
    });
    // Clear cells and refocus the first one.
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _onChanged(int index, String value) {
    if (_error != null) {
      setState(() => _error = null);
    }
    if (value.isEmpty) return;
    final digit = value.characters.last;
    _controllers[index].text = digit;
    _controllers[index].selection = TextSelection.fromPosition(
      const TextPosition(offset: 1),
    );
    if (index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
      _attempt();
    }
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB820), Color(0xFFF59E0B)],
                ),
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 28,
                color: Color(0xFF1A0A05),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Acceso VIP',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Ingresa el código de acceso para desbloquear CineHax y disfrutar de películas y series premium.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ..._buildCells(0, 3),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '—',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                ..._buildCells(3, 6),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _checking
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _checking ? null : _attempt,
                    icon: const Icon(
                      Icons.lock_open_rounded,
                      size: 16,
                      color: Color(0xFF1A0A05),
                    ),
                    label: Text(
                      _checking ? 'Verificando' : 'Desbloquear',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Color(0xFF1A0A05),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB820),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCells(int start, int end) {
    return List.generate(end - start, (i) {
      final index = start + i;
      final filled = _controllers[index].text.isNotEmpty;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: SizedBox(
          width: 38,
          height: 48,
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.backspace) {
                _onBackspace(index);
              }
            },
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(1),
              ],
              maxLength: 1,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: filled ? AppColors.accent2 : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: AppColors.surface2,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: filled ? AppColors.accent2 : AppColors.border,
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: filled ? AppColors.accent2 : AppColors.border,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AppColors.accent,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (value) => _onChanged(index, value),
            ),
          ),
        ),
      );
    });
  }
}
