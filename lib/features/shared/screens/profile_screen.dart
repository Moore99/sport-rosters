import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/router/app_router.dart';
import '../../auth/data/user_repository.dart';
import '../../../core/services/weight_unit_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../teams/domain/team.dart';
import '../../teams/presentation/providers/teams_provider.dart';
import '../providers/ads_provider.dart';

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync  = ref.watch(currentUserProfileProvider);
    final teamsAsync = ref.watch(userTeamsProvider);
    final uid        = ref.watch(currentUserProvider)?.uid ?? '';
    final adFree     = ref.watch(adFreeProvider);
    final iapState   = ref.watch(iapProvider);
    final themeMode  = ref.watch(themeModeProvider);
    final weightUnit = ref.watch(weightUnitProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(top: false, child: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (user) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Profile header ─────────────────────────────────────────
            _ProfileHeader(
              uid:        uid,
              user:       user,
              adFree:     adFree,
              weightUnit: weightUnit,
            ),
            const SizedBox(height: 20),

            // ── My Teams & Roles ───────────────────────────────────────
            Text('My Teams', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            teamsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error:   (e, _) => Text('Could not load teams: $e',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              data: (teams) => teams.isEmpty
                  ? Text('No teams yet.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline))
                  : Column(
                      children: teams.map((t) => _TeamRoleTile(team: t, uid: uid)).toList(),
                    ),
            ),
            const SizedBox(height: 20),

            // ── Appearance ─────────────────────────────────────────────
            Text('Appearance', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.brightness_6_outlined),
                        SizedBox(width: 8),
                        Text('Theme'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode),
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto),
                            label: Text('Auto'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode),
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (modes) => ref
                            .read(themeModeProvider.notifier)
                            .setMode(modes.first),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Icon(Icons.monitor_weight_outlined),
                        SizedBox(width: 8),
                        Text('Weight Unit'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<WeightUnit>(
                        segments: const [
                          ButtonSegment(
                            value: WeightUnit.kg,
                            label: Text('kg'),
                            icon: Icon(Icons.fitness_center),
                          ),
                          ButtonSegment(
                            value: WeightUnit.lbs,
                            label: Text('lbs'),
                            icon: Icon(Icons.scale_outlined),
                          ),
                        ],
                        selected: {weightUnit},
                        onSelectionChanged: (units) => ref
                            .read(weightUnitProvider.notifier)
                            .setUnit(units.first),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Remove Ads ─────────────────────────────────────────────
            if (!adFree) ...[
              Text('Upgrade', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.block, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Remove Ads',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'One-time purchase — removes all ads permanently. '
                        'Synced across your devices.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      if (iapState.state == IapState.error)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            iapState.message ?? 'Purchase failed.',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 13),
                          ),
                        ),
                      FilledButton(
                        onPressed: iapState.state == IapState.loading ||
                                iapState.state == IapState.purchasing
                            ? null
                            : () => ref
                                .read(iapProvider.notifier)
                                .purchaseRemoveAds(),
                        child: iapState.state == IapState.loading ||
                                iapState.state == IapState.purchasing
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Remove Ads'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            ref.read(iapProvider.notifier).restorePurchases(),
                        child: const Text('Restore Purchase'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Legal & Account ────────────────────────────────────────
            Text('Account', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title:   const Text('Help'),
              onTap:   () => context.push(AppRoutes.help),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title:   const Text('Privacy Policy'),
              onTap:   () => context.push(AppRoutes.privacy),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title:   const Text('Terms of Service'),
              onTap:   () => context.push(AppRoutes.terms),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title:   const Text('Sign Out'),
              onTap:   () async {
                await ref.read(authNotifierProvider.notifier).signOut();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Delete Account',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () => _confirmDelete(context, ref),
            ),
            const SizedBox(height: 24),
            Center(
              child: ref.watch(_appVersionProvider).whenOrNull(
                    data: (v) => Text(
                      'Sport Rosters v$v',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  ) ?? const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      )),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _DeleteAccountDialog(ref: ref),
    );
  }
}

// ── Profile header ─────────────────────────────────────────────────────────────

class _ProfileHeader extends ConsumerStatefulWidget {
  final String      uid;
  final dynamic     user;   // AppUser?
  final bool        adFree;
  final WeightUnit  weightUnit;
  const _ProfileHeader({
    required this.uid,
    required this.user,
    required this.adFree,
    required this.weightUnit,
  });

  @override
  ConsumerState<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<_ProfileHeader> {
  bool _uploading = false;

  Future<void> _pickAndUploadPhoto() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      await ref.read(userRepositoryProvider).uploadProfilePhoto(
            widget.uid, File(cropped.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user       = widget.user;
    final photoUrl   = user?.photoUrl as String?;
    final initial    = (user?.name as String?)?.isNotEmpty == true
        ? (user!.name as String).substring(0, 1).toUpperCase()
        : '?';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GestureDetector(
              onTap: _uploading ? null : _pickAndUploadPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 32 * MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5),
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl) as ImageProvider
                        : null,
                    child: photoUrl == null
                        ? Text(initial,
                            style: const TextStyle(fontSize: 24))
                        : null,
                  ),
                  if (_uploading)
                    Positioned.fill(
                      child: CircleAvatar(
                        radius: 32 * MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5),
                        backgroundColor: Colors.black38,
                        child: const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                      ),
                    )
                  else
                    Positioned(
                      bottom: 0, right: 0,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(Icons.camera_alt,
                            size: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.name ?? 'Unknown',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(user?.email ?? '',
                      style: Theme.of(context).textTheme.bodyMedium),
                  if (user?.weightKg != null)
                    Text(
                      formatWeight(
                          user!.weightKg as double, widget.weightUnit),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if ((user?.role as String?) == 'systemAdmin')
                    const Chip(
                      label: Text('System Admin'),
                      avatar: Icon(Icons.admin_panel_settings, size: 16),
                    ),
                  if (widget.adFree)
                    const Chip(
                      label: Text('Ad-free'),
                      avatar: Icon(Icons.star, size: 16),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit profile',
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _EditProfileDialog(
                  uid:           widget.uid,
                  currentName:   user?.name ?? '',
                  currentWeight: user?.weightKg as double?,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit profile dialog ────────────────────────────────────────────────────────

class _EditProfileDialog extends ConsumerStatefulWidget {
  final String  uid;
  final String  currentName;
  final double? currentWeight;
  const _EditProfileDialog({
    required this.uid,
    required this.currentName,
    required this.currentWeight,
  });

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _weightCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentName);
    // Initial value shown in display unit
    final unit = ref.read(weightUnitProvider);
    _weightCtrl = TextEditingController(
      text: widget.currentWeight != null
          ? toDisplayWeight(widget.currentWeight!, unit).toStringAsFixed(1)
          : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty.');
      return;
    }
    double? weightKg;
    final raw = _weightCtrl.text.trim();
    if (raw.isNotEmpty) {
      final parsed = double.tryParse(raw);
      if (parsed == null || parsed <= 0) {
        final unit = ref.read(weightUnitProvider);
        setState(() => _error = 'Enter a valid weight in ${unit.name}.');
        return;
      }
      weightKg = toStorageKg(parsed, ref.read(weightUnitProvider));
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(userRepositoryProvider).updateProfile(
        widget.uid,
        name:     name,
        weightKg: weightKg,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _saving = false; _error = 'Save failed. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller:  _nameCtrl,
            decoration:  const InputDecoration(labelText: 'Display name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final unit = ref.watch(weightUnitProvider);
            return TextField(
              controller:  _weightCtrl,
              decoration: InputDecoration(
                labelText: 'Weight (${unit.name})',
                hintText:  'Optional — used for dragon boat balance',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            );
          }),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Delete account dialog ──────────────────────────────────────────────────────

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _DeleteAccountDialog({required this.ref});

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  bool _deleting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently deletes your account and all associated data '
            '(availability, rankings, drop-in history).\n\n'
            'This action cannot be undone.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _deleting ? null : _deleteAccount,
          child: _deleting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Delete Account'),
        ),
      ],
    );
  }

  Future<void> _deleteAccount() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'northamerica-northeast1');
      await fn.httpsCallable('deleteAccount').call();
      if (mounted) Navigator.of(context).pop();
      await widget.ref.read(authNotifierProvider.notifier).signOut();
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _deleting = false;
        _error = e.message ?? 'Deletion failed. Please try again.';
      });
    } catch (e) {
      setState(() {
        _deleting = false;
        _error = 'Unexpected error. Please try again.';
      });
    }
  }
}

// ── Team role tile ─────────────────────────────────────────────────────────────

class _TeamRoleTile extends StatelessWidget {
  final Team   team;
  final String uid;
  const _TeamRoleTile({required this.team, required this.uid});

  @override
  Widget build(BuildContext context) {
    final isAdmin = team.isAdmin(uid);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 20 * MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5),
        child: Text(team.sport.substring(0, 1)),
      ),
      title: Text(team.name),
      subtitle: Text(team.sport),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.tune, size: 20),
            tooltip: 'My Position Preferences',
            onPressed: () => context.push(
              '/teams/${team.teamId}/preferences/$uid'
              '?sport=${Uri.encodeComponent(team.sport)}&name=',
            ),
          ),
          Chip(
            label: Text(isAdmin ? 'Team Admin' : 'Player',
                style: const TextStyle(fontSize: 12)),
            avatar: Icon(
              isAdmin ? Icons.manage_accounts : Icons.person,
              size: 16,
            ),
            backgroundColor: isAdmin
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}
