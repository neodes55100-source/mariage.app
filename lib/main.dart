import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';

import 'app_config.dart';
import 'sync_service.dart';
import 'upload_service.dart';

const _red = Color(0xFFB20E22);
const _deepRed = Color(0xFF89111D);
const _gold = Color(0xFFC7A35A);
const _cream = Color(0xFFFFFCF8);
const _paper = Color(0xFFFFF9F3);
const _soft = Color(0xFFF7EEE6);
const _ink = Color(0xFF2A211D);

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await SyncService.sync(background: true);
      return true;
    } catch (_) {
      return false;
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await Workmanager().initialize(callbackDispatcher);
  }
  runApp(const WeddingApp());
}

class WeddingApp extends StatelessWidget {
  const WeddingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mariage Emmanuel & Jennifer',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _cream,
        colorScheme: ColorScheme.fromSeed(seedColor: _red),
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: _ink,
              displayColor: _ink,
            ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          hintStyle: const TextStyle(color: Colors.black38),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFDCCABC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFDCCABC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: _red, width: 1.6),
          ),
        ),
      ),
      home: const WeddingShell(),
    );
  }
}

class WeddingShell extends StatefulWidget {
  const WeddingShell({super.key});

  @override
  State<WeddingShell> createState() => _WeddingShellState();
}

class _WeddingShellState extends State<WeddingShell>
    with WidgetsBindingObserver {
  static const _onboardingKey = 'onboarding_done_maquette_v2';
  static const _recentNamesKey = 'recent_upload_names';

  final _nameController = TextEditingController();

  int _tab = 0;
  int _onboardingStep = 0;
  bool _showSplash = true;
  bool _onboardingDone = false;
  bool _enabled = false;
  bool _busy = true;
  bool _manualUploading = false;
  bool _syncing = false;
  bool _allUpToDate = false;
  int _sentCount = 0;
  int _uploadDone = 0;
  int _uploadTotal = 0;
  DateTime? _personalAutoEnd;
  String _message = '';
  List<String> _recentNames = <String>[];

  bool get _eveningEnded => _personalAutoEnd != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _enabled) {
      _syncNow(silent: true);
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = await SyncService.getGuestName();
    _enabled = await SyncService.isAutoEnabled();
    _sentCount = await SyncService.sentCount();
    _personalAutoEnd = await SyncService.getPersonalAutoEnd();
    _onboardingDone = prefs.getBool(_onboardingKey) ?? false;
    _recentNames = prefs.getStringList(_recentNamesKey) ?? <String>[];

    if (!mounted) return;
    setState(() => _busy = false);
    await Future<void>.delayed(const Duration(milliseconds: 1450));
    if (mounted) setState(() => _showSplash = false);
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (!mounted) return;
    setState(() {
      _onboardingDone = true;
      _tab = 1;
      _onboardingStep = 0;
    });
  }

  Future<String?> _guestName() async {
    var name = _nameController.text.trim();
    if (name.length >= 2) {
      await SyncService.setGuestName(name);
      return name;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cream,
        title: const Text(
          'Un dernier détail',
          style: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Votre prénom'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: _ink)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 2) Navigator.pop(context, value);
            },
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null) return null;
    name = result.trim();
    _nameController.text = name;
    await SyncService.setGuestName(name);
    if (mounted) setState(() {});
    return name;
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    String confirmLabel = 'Confirmer',
    bool danger = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _cream,
            title: Text(
              title,
              style: const TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            content: Text(body, style: const TextStyle(height: 1.35)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler', style: TextStyle(color: _ink)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: danger ? _deepRed : _red,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _registerAutoTask() async {
    if (!Platform.isAndroid) return;
    await Workmanager().registerPeriodicTask(
      AppConfig.backgroundUniqueName,
      AppConfig.backgroundTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  Future<void> _cancelAutoTask() async {
    if (!Platform.isAndroid) return;
    await Workmanager().cancelByUniqueName(AppConfig.backgroundUniqueName);
  }

  Future<void> _saveNameAndEnable() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _message = 'Entre ton prénom pour continuer.');
      return;
    }
    await SyncService.setGuestName(name);
    await _finishOnboarding();
    await _enableAuto(skipNameCheck: true);
  }

  Future<void> _enableAuto({
    bool resetPersonalEnd = false,
    bool skipNameCheck = false,
  }) async {
    final name = skipNameCheck ? _nameController.text.trim() : await _guestName();
    if (name == null || name.length < 2) return;

    if (_eveningEnded && !resetPersonalEnd) {
      final ok = await _confirm(
        title: 'Réactiver le partage automatique ?',
        body:
            'Tu avais indiqué que ta soirée était terminée. En réactivant, les nouveaux médias pris jusqu’à 05:00 pourront de nouveau être envoyés.',
        confirmLabel: 'Réactiver',
      );
      if (!ok) return;
      resetPersonalEnd = true;
    }

    setState(() {
      _busy = true;
      _message = '';
      _allUpToDate = false;
    });

    try {
      final permission = await SyncService.requestPhotoPermission();
      if (!permission.hasAccess) {
        setState(() {
          _message =
              'L’accès aux photos et vidéos est nécessaire pour le partage automatique.';
        });
        return;
      }

      if (resetPersonalEnd) {
        await SyncService.clearPersonalAutoEnd();
        _personalAutoEnd = null;
      }

      await SyncService.setGuestName(name);
      await SyncService.setAutoEnabled(true);
      await _registerAutoTask();
      _enabled = true;
      _message = 'Partage automatique activé.';
      await _syncNow(silent: true);
    } catch (e) {
      _message = 'Impossible d’activer le partage : $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pauseAuto() async {
    await SyncService.setAutoEnabled(false);
    await _cancelAutoTask();
    if (!mounted) return;
    setState(() {
      _enabled = false;
      _allUpToDate = false;
      _message = 'Partage automatique en pause.';
    });
  }

  Future<void> _finishEvening() async {
    final ok = await _confirm(
      title: 'Fin de soirée ?',
      body:
          'Le partage automatique va s’arrêter immédiatement sur ce téléphone. Aucun média pris après cette heure ne sera envoyé automatiquement. Les envois manuels resteront disponibles.',
      confirmLabel: 'Terminer le partage',
      danger: true,
    );
    if (!ok) return;

    final end = DateTime.now();
    await SyncService.setPersonalAutoEnd(end);
    await SyncService.setAutoEnabled(false);
    await _cancelAutoTask();

    if (!mounted) return;
    setState(() {
      _enabled = false;
      _personalAutoEnd = end;
      _allUpToDate = false;
      _message =
          'Partage arrêté à ${_clock(end)}. Aucun média pris après cette heure ne sera envoyé automatiquement.';
    });
  }

  Future<void> _syncNow({bool silent = false}) async {
    if (!_enabled) return;
    if (!silent && mounted) {
      setState(() {
        _syncing = true;
        _allUpToDate = false;
        _message = '';
      });
    }

    try {
      final report = await SyncService.sync();
      _sentCount = await SyncService.sentCount();
      if (!silent && mounted) {
        setState(() {
          _allUpToDate = true;
          _message = report.uploaded > 0
              ? '${report.uploaded} nouveau(x) média(s) envoyé(s).'
              : 'Tout est à jour !';
        });
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() => _message = 'Synchronisation impossible : $e');
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String? _mimeFor(String name) {
    final ext = name.toLowerCase().split('.').last;
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      'gif' => 'image/gif',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      _ => null,
    };
  }

  Future<void> _manualUpload() async {
    final name = await _guestName();
    if (name == null) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;

    setState(() {
      _tab = 1;
      _manualUploading = true;
      _uploadDone = 0;
      _uploadTotal = picked.files.length;
      _message = '';
      _allUpToDate = false;
    });

    int uploaded = 0;
    int failed = 0;
    final uploadedNames = <String>[];
    final uploader = UploadService();

    try {
      for (final item in picked.files) {
        final path = item.path;
        if (path == null || !await File(path).exists()) {
          failed++;
          _uploadDone++;
          if (mounted) setState(() {});
          continue;
        }

        try {
          final result = await uploader.uploadFile(
            file: File(path),
            guestName: name,
            originalName: item.name,
            mimeType: _mimeFor(item.name),
            uploadSource: 'manual',
          );
          if (result.ok) {
            uploaded++;
            uploadedNames.add(item.name);
          } else {
            failed++;
          }
        } catch (_) {
          failed++;
        }

        _uploadDone++;
        if (mounted) setState(() {});
      }
    } finally {
      uploader.close();
    }

    if (uploaded > 0) {
      final prefs = await SharedPreferences.getInstance();
      _sentCount = (prefs.getInt('sent_count') ?? 0) + uploaded;
      await prefs.setInt('sent_count', _sentCount);
      _recentNames = [...uploadedNames.reversed, ..._recentNames].take(12).toList();
      await prefs.setStringList(_recentNamesKey, _recentNames);
    }

    if (!mounted) return;
    setState(() {
      _manualUploading = false;
      _allUpToDate = failed == 0;
      _message = failed == 0
          ? '$uploaded média(s) envoyé(s) avec succès.'
          : '$uploaded envoyé(s), $failed échec(s).';
    });
  }

  Future<void> _openWebsite() async {
    final uri = Uri.parse('https://www.creemachanson.com');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le site pour le moment.')),
      );
    }
  }

  String _clock(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _dateTimeLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à ${_clock(d)}';

  Widget _flowerCorner({required bool right, required bool bottom}) {
    return Positioned(
      top: bottom ? null : -18,
      bottom: bottom ? -18 : null,
      left: right ? null : -18,
      right: right ? -18 : null,
      child: Transform.rotate(
        angle: right ? .35 : -.35,
        child: Opacity(
          opacity: .16,
          child: Icon(
            Icons.local_florist,
            size: 112,
            color: right ? _deepRed : _red,
          ),
        ),
      ),
    );
  }

  Widget _decoratedPage(Widget child) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: _cream)),
        _flowerCorner(right: false, bottom: false),
        _flowerCorner(right: true, bottom: false),
        _flowerCorner(right: false, bottom: true),
        _flowerCorner(right: true, bottom: true),
        Positioned.fill(child: child),
      ],
    );
  }

  Widget _ringsMark({double size = 82}) {
    return SizedBox(
      width: size * 1.35,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: size * .12,
            child: Container(
              width: size * .66,
              height: size * .66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _gold, width: 7),
                boxShadow: const [
                  BoxShadow(color: Color(0x22C7A35A), blurRadius: 10),
                ],
              ),
            ),
          ),
          Positioned(
            right: size * .12,
            top: size * .20,
            child: Container(
              width: size * .66,
              height: size * .66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _gold, width: 7),
                boxShadow: const [
                  BoxShadow(color: Color(0x22C7A35A), blurRadius: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heartDivider({double width = 250}) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(child: Divider(color: _red.withValues(alpha: .25))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.favorite, color: _red, size: 14),
          ),
          Expanded(child: Divider(color: _red.withValues(alpha: .25))),
        ],
      ),
    );
  }

  Widget _coupleHeader({bool compact = false}) {
    return Column(
      children: [
        Text(
          'Emmanuel & Jennifer',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'cursive',
            fontStyle: FontStyle.italic,
            fontSize: compact ? 31 : 38,
            color: _deepRed,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 8),
        _heartDivider(width: compact ? 240 : 270),
        const SizedBox(height: 7),
        const Text(
          'NOTRE MARIAGE',
          style: TextStyle(
            letterSpacing: 2.1,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ],
    );
  }

  Widget _title(String text) {
    return Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 29,
            fontWeight: FontWeight.w700,
            color: _ink,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 9),
        _heartDivider(),
      ],
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: _red,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
  }

  ButtonStyle _outlineButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _deepRed,
      minimumSize: const Size.fromHeight(54),
      side: const BorderSide(color: _red, width: 1.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29)),
      textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
    );
  }

  Widget _splash() {
    return _decoratedPage(
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 38, 26, 36),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _ringsMark(size: 92),
              const SizedBox(height: 22),
              const Text(
                'Emmanuel & Jennifer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'cursive',
                  fontStyle: FontStyle.italic,
                  fontSize: 42,
                  height: 1.05,
                  color: _deepRed,
                ),
              ),
              const SizedBox(height: 18),
              _heartDivider(width: 285),
              const SizedBox(height: 12),
              const Text(
                'NOTRE MARIAGE',
                style: TextStyle(
                  letterSpacing: 2.3,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '03 juillet 2027',
                style: TextStyle(fontSize: 16.5, color: Colors.black54),
              ),
              const SizedBox(height: 27),
              const Text(
                'Partagez vos plus beaux souvenirs avec nous',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16.5, height: 1.4),
              ),
              const Spacer(flex: 3),
              const Text(
                'Merci d’être là !',
                style: TextStyle(
                  fontFamily: 'cursive',
                  fontStyle: FontStyle.italic,
                  color: _deepRed,
                  fontSize: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _onboarding() {
    return switch (_onboardingStep) {
      0 => _welcomeStep(),
      1 => _permissionStep(),
      _ => _nameStep(),
    };
  }

  Widget _welcomeStep() {
    return _decoratedPage(
      SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
          children: [
            _coupleHeader(compact: true),
            const SizedBox(height: 46),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _featureIcon(Icons.photo_camera_outlined),
                const SizedBox(width: 26),
                _featureIcon(Icons.videocam_outlined),
              ],
            ),
            const SizedBox(height: 34),
            const Text(
              'Partagez vos photos\net vidéos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 29,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Capturez chaque instant et revivez ensemble\nla magie de cette journée !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.5, height: 1.45),
            ),
            const SizedBox(height: 46),
            FilledButton(
              onPressed: () => setState(() => _onboardingStep = 1),
              style: _primaryButtonStyle(),
              child: const Text('Commencer'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _showInfoDialog,
              child: const Text(
                'En savoir plus',
                style: TextStyle(
                  color: _ink,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureIcon(IconData icon) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        border: Border.all(color: _deepRed, width: 2.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: _deepRed, size: 42),
    );
  }

  Future<void> _showInfoDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cream,
        title: const Text(
          'Comment ça marche ?',
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Tu peux envoyer manuellement les photos et vidéos de ton choix. Si tu actives le partage automatique, seules celles prises pendant la période du mariage sont envoyées. Tu peux arrêter le partage à tout moment avec le bouton « Fin de soirée ».',
          style: TextStyle(height: 1.45),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  Widget _permissionStep() {
    return _decoratedPage(
      SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 34, 28, 30),
          children: [
            _title('Partage automatique'),
            const SizedBox(height: 32),
            Center(child: _shareIllustration()),
            const SizedBox(height: 27),
            const Text(
              'Autorisez l’accès à vos photos\net vidéos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 26),
            _checkLine(
              'Toutes les photos et vidéos prises pendant le mariage seront automatiquement envoyées',
            ),
            _checkLine(
              'Seuls les médias pris pendant l’événement seront partagés',
            ),
            _checkLine('Vos photos restent privées ailleurs'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        final permission =
                            await SyncService.requestPhotoPermission();
                        if (!mounted) return;
                        if (permission.hasAccess) {
                          setState(() {
                            _onboardingStep = 2;
                            _message = '';
                          });
                        } else {
                          setState(() {
                            _message =
                                'Autorisation refusée. Tu pourras l’activer plus tard depuis l’onglet Statut.';
                          });
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              style: _primaryButtonStyle(),
              child: const Text('J’autorise'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await _finishOnboarding();
                if (mounted) setState(() => _tab = 0);
              },
              child: const Text('Plus tard', style: TextStyle(color: _ink)),
            ),
            _messageBox(),
          ],
        ),
      ),
    );
  }

  Widget _shareIllustration() {
    return SizedBox(
      width: 190,
      height: 105,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            child: Container(
              width: 68,
              height: 92,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF665950), width: 2),
              ),
              child: const Icon(Icons.photo_library_outlined,
                  color: _deepRed, size: 36),
            ),
          ),
          const Positioned(
            left: 77,
            child: Icon(Icons.arrow_forward_rounded, color: _gold, size: 34),
          ),
          Positioned(
            right: 2,
            child: Container(
              width: 80,
              height: 72,
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.cloud_upload_outlined,
                  color: _red, size: 47),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.check_circle, color: _red, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 15.3, height: 1.3)),
          ),
        ],
      ),
    );
  }

  Widget _nameStep() {
    return _decoratedPage(
      SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 50, 28, 30),
          children: [
            _title('Un dernier détail'),
            const SizedBox(height: 34),
            const Icon(Icons.person_outline, size: 70, color: _deepRed),
            const SizedBox(height: 24),
            const Text(
              'Entrez votre prénom pour identifier vos médias',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _nameController,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Votre prénom'),
              onChanged: (_) {
                if (_message.isNotEmpty) setState(() => _message = '');
              },
            ),
            const SizedBox(height: 26),
            FilledButton(
              onPressed: _busy ? null : _saveNameAndEnable,
              style: _primaryButtonStyle(),
              child: const Text('Continuer'),
            ),
            const SizedBox(height: 13),
            const Text(
              'Vous pourrez le modifier plus tard',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            _messageBox(),
          ],
        ),
      ),
    );
  }

  Widget _home() {
    return _decoratedPage(
      SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 30),
          children: [
            _coupleHeader(compact: true),
            const SizedBox(height: 38),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _featureIcon(Icons.photo_camera_outlined),
                const SizedBox(width: 25),
                _featureIcon(Icons.videocam_outlined),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Partagez vos photos\net vidéos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 17),
            const Text(
              'Capturez chaque instant et revivez ensemble\nla magie de cette journée !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 34),
            FilledButton(
              onPressed: _busy ? null : _manualUpload,
              style: _primaryButtonStyle(),
              child: const Text('Déposer mes photos / vidéos'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() => _tab = 1),
              style: _outlineButtonStyle(),
              child: Text(
                _enabled
                    ? 'Voir le partage automatique'
                    : _eveningEnded
                        ? 'Partage terminé'
                        : 'Activer le partage automatique',
              ),
            ),
            _messageBox(),
          ],
        ),
      ),
    );
  }

  Widget _status() {
    if (_manualUploading || _syncing) return _sendingStatus();
    if (_allUpToDate && _enabled) return _upToDateStatus();
    if (_eveningEnded && !_enabled) return _endedStatus();
    if (!_enabled) return _inactiveStatus();
    return _activeStatus();
  }

  Widget _inactiveStatus() {
    return _decoratedPage(
      SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 30),
          children: [
            _title('Partage automatique'),
            const SizedBox(height: 29),
            Center(child: _shareIllustration()),
            const SizedBox(height: 24),
            const Text(
              'Autorisez l’accès à vos photos\net vidéos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.w700,
                fontSize: 21.5,
              ),
            ),
            const SizedBox(height: 22),
            _checkLine(
              'Toutes les photos et vidéos prises pendant le mariage seront automatiquement envoyées',
            ),
            _checkLine(
              'Seuls les médias pris pendant l’événement seront partagés',
            ),
            _checkLine('Vos photos restent privées ailleurs'),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : _enableAuto,
              style: _primaryButtonStyle(),
              child: const Text('J’autorise'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _tab = 0),
              child: const Text('Plus tard', style: TextStyle(color: _ink)),
            ),
            _messageBox(),
          ],
        ),
      ),
    );
  }

  Widget _activeStatus() {
    return _decoratedPage(
      SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 38, 28, 28),
          children: [
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: _red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 51),
                  ),
                  const Positioned(
                    top: 0,
                    right: -2,
                    child: Icon(Icons.auto_awesome, color: _gold, size: 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'Partage automatique activé !',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 27,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Toutes les photos et vidéos que vous prenez pendant le mariage seront automatiquement envoyées.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15.5, height: 1.45),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEADBD0)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.calendar_month_outlined, color: _deepRed, size: 25),
                  SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      'Période de partage\n03 juil. 2027 — 14:00\nau 04 juil. 2027 — 05:00',
                      style: TextStyle(height: 1.45, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _busy ? null : _finishEvening,
              style: _outlineButtonStyle(),
              child: const Text('Fin de soirée — arrêter le partage'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => _syncNow(),
              child: const Text(
                'Synchroniser maintenant',
                style: TextStyle(color: _deepRed, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _pauseAuto,
              child: const Text(
                'Mettre en pause',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            _messageBox(),
          ],
        ),
      ),
    );
  }

  Widget _sendingStatus() {
    final total = _manualUploading ? _uploadTotal : (_sentCount + 1);
    final done = _manualUploading ? _uploadDone : _sentCount;
    final progress = _manualUploading && total > 0
        ? (_uploadDone / total).clamp(0.0, 1.0)
        : null;

    return _decoratedPage(
      SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 44, 28, 30),
          children: [
            const Text(
              'Envoi en cours...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.cloud_upload_outlined, color: _red, size: 78),
            const SizedBox(height: 8),
            Text(
              '$done médias envoyés',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              borderRadius: BorderRadius.circular(6),
              color: _red,
              backgroundColor: const Color(0xFFE9D7C8),
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                4,
                (index) => Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFFE5D4C3)),
                  ),
                  child: const Icon(Icons.image_outlined, color: _deepRed),
                ),
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'Les médias sont envoyés en arrière-plan.\nVous pouvez continuer à utiliser votre téléphone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Colors.black54, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _upToDateStatus() {
    return _decoratedPage(
      SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 56, 28, 30),
          children: [
            Center(
              child: Container(
                width: 87,
                height: 87,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF2F0DF),
                  border: Border.all(color: _gold, width: 2.5),
                ),
                child: const Icon(Icons.check, color: Color(0xFF71802F), size: 52),
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Tout est à jour !',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              '$_sentCount médias envoyés',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                children: [
                  Text(
                    'Merci de partager ces beaux souvenirs avec nous !',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15.5, height: 1.4),
                  ),
                  SizedBox(height: 12),
                  Icon(Icons.favorite, color: _red, size: 24),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => setState(() => _allUpToDate = false),
              style: _outlineButtonStyle(),
              child: const Text('Retour au statut'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _tab = 2),
              child: const Text(
                'Voir mes derniers envois',
                style: TextStyle(color: _deepRed, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _endedStatus() {
    final end = _personalAutoEnd!;
    return _decoratedPage(
      SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 44, 28, 30),
          children: [
            _title('Partage terminé'),
            const SizedBox(height: 31),
            const Icon(Icons.nightlight_round, color: _deepRed, size: 72),
            const SizedBox(height: 20),
            const Text(
              'Bonne fin de soirée !',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 27,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Le partage automatique a été arrêté le ${_dateTimeLabel(end)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15.5, height: 1.45),
            ),
            const SizedBox(height: 15),
            const Text(
              'Aucun média pris après cette heure ne sera envoyé automatiquement.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _manualUpload,
              style: _primaryButtonStyle(),
              child: const Text('Envoyer manuellement'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _enableAuto(resetPersonalEnd: false),
              child: const Text(
                'J’ai cliqué par erreur — réactiver',
                style: TextStyle(color: _deepRed, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gallery() {
    final names = _recentNames;
    return _decoratedPage(
      SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          children: [
            const Text(
              'Vos derniers envois',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 27,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _heartDivider(),
            const SizedBox(height: 20),
            if (names.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        color: _deepRed, size: 58),
                    const SizedBox(height: 13),
                    Text(
                      '$_sentCount média(s) envoyé(s)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Les prochains envois apparaîtront ici.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: names.length > 9 ? 9 : names.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemBuilder: (context, index) {
                  final name = names[index];
                  final isVideo = <String>['mp4', 'mov', 'm4v']
                      .contains(name.toLowerCase().split('.').last);
                  final isLast = index == 8 && names.length > 9;
                  return Container(
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFFE5D4C3)),
                    ),
                    child: Center(
                      child: isLast
                          ? Text(
                              '+${names.length - 8}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : Icon(
                              isVideo
                                  ? Icons.play_circle_outline
                                  : Icons.image_outlined,
                              color: _deepRed,
                              size: 34,
                            ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: _manualUpload,
              style: _outlineButtonStyle(),
              child: const Text('Ajouter des photos / vidéos'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _more() {
    return _decoratedPage(
      SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
          children: [
            _title('Plus'),
            const SizedBox(height: 22),
            _settingCard(
              Icons.person_outline,
              'Prénom',
              _nameController.text.trim().isEmpty
                  ? 'Non renseigné'
                  : _nameController.text.trim(),
            ),
            _settingCard(
              Icons.shield_outlined,
              'Confidentialité',
              'Seuls les médias choisis manuellement ou pris pendant la période du mariage sont envoyés.',
            ),
            _settingCard(
              Icons.schedule_outlined,
              'Période automatique',
              '03/07/2027 14:00 → 04/07/2027 05:00',
            ),
            if (_enabled)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 16),
                child: OutlinedButton(
                  onPressed: _finishEvening,
                  style: _outlineButtonStyle(),
                  child: const Text('Fin de soirée — arrêter le partage'),
                ),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .86),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6D8CE)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.favorite_border, color: _deepRed, size: 28),
                  const SizedBox(height: 10),
                  const Text(
                    'Application réalisée par',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manu D Studio',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'pour',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  TextButton(
                    onPressed: _openWebsite,
                    child: const Text(
                      'www.creemachanson.com',
                      style: TextStyle(
                        color: _deepRed,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Text(
                    '© Manu D Studio 2026/2027',
                    style: TextStyle(color: Colors.black45, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingCard(IconData icon, String title, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5D4C3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _deepRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(color: Colors.black54, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBox() {
    if (_message.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
      ),
    );
  }

  Widget _bottomNav() {
    return BottomNavigationBar(
      currentIndex: _tab,
      onTap: (value) => setState(() {
        _tab = value;
        if (value != 1) _allUpToDate = false;
      }),
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xFFFFFEFC),
      selectedItemColor: _red,
      unselectedItemColor: const Color(0xFF4D4845),
      selectedFontSize: 11.5,
      unselectedFontSize: 11.5,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.check_circle_outline),
          activeIcon: Icon(Icons.check_circle),
          label: 'Statut',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.photo_library_outlined),
          activeIcon: Icon(Icons.photo_library),
          label: 'Galerie',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.more_horiz),
          activeIcon: Icon(Icons.more_horiz),
          label: 'Plus',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return Scaffold(body: _splash());

    if (!_onboardingDone) {
      return Scaffold(
        backgroundColor: _cream,
        body: _onboarding(),
      );
    }

    final pages = [_home(), _status(), _gallery(), _more()];
    return Scaffold(
      backgroundColor: _cream,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _bottomNav(),
    );
  }
}
