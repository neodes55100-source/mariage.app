import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';

import 'app_config.dart';
import 'rose_asset.dart';
import 'sync_service.dart';
import 'upload_service.dart';

const _red = Color(0xFFB40F22);
const _deepRed = Color(0xFF92111D);
const _gold = Color(0xFFC9A14A);
const _cream = Color(0xFFFFFCF8);
const _soft = Color(0xFFF7EEE4);
const _ink = Color(0xFF251F1B);
const _olive = Color(0xFF777D35);
const _line = Color(0xFFD8A9A1);

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
  runApp(const WeddingAppV4());
}

class WeddingAppV4 extends StatelessWidget {
  const WeddingAppV4({super.key});

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
          fillColor: const Color(0xFFFFFDF9),
          hintStyle: const TextStyle(color: Color(0xFF9D8E83)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD7B58D), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _red, width: 1.4),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
  static const _onboardingKey = 'onboarding_done_maquette_v4';
  static const _recentNamesKey = 'recent_upload_names';

  final TextEditingController _nameController = TextEditingController();

  bool _showSplash = true;
  bool _onboardingDone = false;
  int _onboardingStep = 0;
  int _tab = 0;
  bool _busy = true;
  bool _enabled = false;
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
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _showSplash = false);
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (!mounted) return;
    setState(() {
      _onboardingDone = true;
      _onboardingStep = 0;
      _tab = 0;
    });
  }

  Future<String?> _ensureGuestName() async {
    final current = _nameController.text.trim();
    if (current.length >= 2) {
      await SyncService.setGuestName(current);
      return current;
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
            fontSize: 24,
            fontWeight: FontWeight.w700,
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
    _nameController.text = result;
    await SyncService.setGuestName(result);
    return result;
  }

  Future<bool> _confirm(String title, String body, String label) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _cream,
            title: Text(
              title,
              style: const TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(body, style: const TextStyle(height: 1.4)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler', style: TextStyle(color: _ink)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _red),
                onPressed: () => Navigator.pop(context, true),
                child: Text(label),
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

  Future<void> _enableAuto({
    bool fromOnboarding = false,
    bool resetPersonalEnd = false,
  }) async {
    final name = fromOnboarding
        ? _nameController.text.trim()
        : await _ensureGuestName();
    if (name == null || name.length < 2) {
      if (mounted) setState(() => _message = 'Entre ton prénom pour continuer.');
      return;
    }

    if (_eveningEnded && !resetPersonalEnd) {
      final ok = await _confirm(
        'Réactiver le partage automatique ?',
        'Tu avais indiqué que ta soirée était terminée. Les nouveaux médias pourront de nouveau être envoyés jusqu’à la fin de la période.',
        'Réactiver',
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
        setState(() => _message =
            'L’accès aux photos et vidéos est nécessaire pour le partage automatique.');
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
      if (fromOnboarding) await _finishOnboarding();
      await _syncNow(silent: true);
      if (mounted) setState(() => _tab = 1);
    } catch (e) {
      if (mounted) setState(() => _message = 'Impossible d’activer le partage : $e');
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
      'Fin de soirée ?',
      'Le partage automatique va s’arrêter immédiatement sur ce téléphone. Aucun média pris après cette heure ne sera envoyé automatiquement. Les envois manuels restent disponibles.',
      'Terminer le partage',
    );
    if (!ok) return;
    final now = DateTime.now();
    await SyncService.setPersonalAutoEnd(now);
    await SyncService.setAutoEnabled(false);
    await _cancelAutoTask();
    if (!mounted) return;
    setState(() {
      _personalAutoEnd = now;
      _enabled = false;
      _allUpToDate = false;
      _tab = 1;
      _message = '';
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
    final name = await _ensureGuestName();
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
      _allUpToDate = false;
      _message = '';
    });

    int uploaded = 0;
    int failed = 0;
    final names = <String>[];
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
            names.add(item.name);
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
      _recentNames = [...names.reversed, ..._recentNames].take(15).toList();
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
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  TextStyle get _scriptStyle => const TextStyle(
        fontFamily: 'cursive',
        fontStyle: FontStyle.italic,
        color: _deepRed,
        fontWeight: FontWeight.w400,
      );

  Widget _fitCanvas({
    required double height,
    required Widget child,
    Alignment alignment = Alignment.topCenter,
  }) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: alignment,
              child: SizedBox(width: 390, height: height, child: child),
            ),
          );
        },
      ),
    );
  }

  Widget _heartDivider({double width = 210}) {
    return SizedBox(
      width: width,
      child: Row(
        children: const [
          Expanded(child: Divider(color: _line, thickness: .7)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 11),
            child: Icon(Icons.favorite, color: _red, size: 15),
          ),
          Expanded(child: Divider(color: _line, thickness: .7)),
        ],
      ),
    );
  }

  Widget _coupleHeader({double nameSize = 31}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Emmanuel & Jennifer',
          textAlign: TextAlign.center,
          style: _scriptStyle.copyWith(fontSize: nameSize),
        ),
        const SizedBox(height: 8),
        _heartDivider(width: 220),
        const SizedBox(height: 9),
        const Text(
          'NOTRE MARIAGE',
          style: TextStyle(
            fontSize: 12.5,
            letterSpacing: 2.7,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  ButtonStyle _primaryStyle({double height = 54}) {
    return FilledButton.styleFrom(
      backgroundColor: _red,
      foregroundColor: Colors.white,
      minimumSize: Size.fromHeight(height),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  ButtonStyle _outlineStyle({double height = 52}) {
    return OutlinedButton.styleFrom(
      foregroundColor: _deepRed,
      minimumSize: Size.fromHeight(height),
      side: const BorderSide(color: _red, width: 1.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  Widget _splash() {
    return _fitCanvas(
      height: 780,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _cream)),
          Positioned(
            left: -5,
            top: -2,
            child: Image.memory(
              roseClusterBytes,
              width: 126,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            right: -2,
            top: 4,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(-1, 1, 1),
              child: Image.memory(
                roseClusterBytes,
                width: 124,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          Positioned(
            left: 6,
            bottom: 9,
            child: Transform.rotate(
              angle: 3.141592653589793,
              child: Image.memory(
                roseClusterBytes,
                width: 94,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 9,
            child: Transform.rotate(
              angle: 3.141592653589793,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(-1, 1, 1),
                child: Image.memory(
                  roseClusterBytes,
                  width: 92,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
          Positioned(
            left: 109,
            top: 91,
            width: 172,
            height: 172,
            child: Image.network(
              'https://mariage.creemachanson.com/assets/img/rings-design2-final-20260914.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.favorite,
                color: _gold,
                size: 72,
              ),
            ),
          ),
          Positioned(
            left: 34,
            right: 34,
            top: 270,
            child: Text(
              'Emmanuel\n& Jennifer',
              textAlign: TextAlign.center,
              style: _scriptStyle.copyWith(fontSize: 38, height: 1.05),
            ),
          ),
          Positioned(left: 100, right: 100, top: 357, child: _heartDivider(width: 190)),
          const Positioned(
            left: 40,
            right: 40,
            top: 392,
            child: Text(
              'Notre Mariage',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'serif', fontSize: 18, letterSpacing: 1.7),
            ),
          ),
          const Positioned(
            left: 40,
            right: 40,
            top: 425,
            child: Text(
              '03 juillet 2027',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: Color(0xFF77706B)),
            ),
          ),
          const Positioned(
            left: 46,
            right: 46,
            top: 485,
            child: Text(
              'Partagez vos plus beaux\nsouvenirs avec nous',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.42),
            ),
          ),
          Positioned(
            left: 25,
            right: 25,
            bottom: 42,
            child: Text(
              'Merci d’être là !',
              textAlign: TextAlign.center,
              style: _scriptStyle.copyWith(fontSize: 29),
            ),
          ),
        ],
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
    return _fitCanvas(
      height: 720,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _cream)),
          Positioned(left: 35, right: 35, top: 36, child: _coupleHeader()),
          Positioned(
            top: 183,
            left: 106,
            child: _featureIcon(Icons.photo_camera_outlined),
          ),
          Positioned(
            top: 183,
            right: 106,
            child: _featureIcon(Icons.videocam_outlined),
          ),
          const Positioned(
            left: 35,
            right: 35,
            top: 295,
            child: Text(
              'Partagez vos photos\net vidéos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 29,
                height: 1.02,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Positioned(
            left: 44,
            right: 44,
            top: 386,
            child: Text(
              'Capturez chaque instant et\nrevivez ensemble la magie\nde cette journée !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.42),
            ),
          ),
          Positioned(
            left: 34,
            right: 34,
            top: 510,
            child: FilledButton(
              onPressed: () => setState(() => _onboardingStep = 1),
              style: _primaryStyle(),
              child: const Text('Commencer'),
            ),
          ),
          Positioned(
            left: 110,
            right: 110,
            top: 571,
            child: TextButton(
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
          ),
        ],
      ),
    );
  }

  Widget _featureIcon(IconData icon) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _deepRed, width: 2),
      ),
      child: Icon(icon, color: _deepRed, size: 45),
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
          'Tu peux envoyer manuellement les photos et vidéos de ton choix. Le partage automatique envoie uniquement les médias pris pendant la période du mariage. Tu peux l’arrêter à tout moment avec « Fin de soirée ».',
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
    return _fitCanvas(
      height: 720,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _cream)),
          const Positioned(
            left: 35,
            right: 35,
            top: 36,
            child: Text(
              'Partage automatique',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'serif', fontSize: 27, fontWeight: FontWeight.w700),
            ),
          ),
          Positioned(left: 85, right: 85, top: 76, child: _heartDivider(width: 220)),
          const Positioned(left: 111, top: 116, child: _ShareIllustration()),
          const Positioned(
            left: 35,
            right: 35,
            top: 242,
            child: Text(
              'Autorisez l’accès à vos photos\net vidéos',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'serif', fontSize: 21, fontWeight: FontWeight.w700, height: 1.12),
            ),
          ),
          Positioned(left: 36, right: 36, top: 323, child: _permissionBullets()),
          Positioned(
            left: 34,
            right: 34,
            top: 547,
            child: FilledButton(
              onPressed: _busy ? null : _permissionNext,
              style: _primaryStyle(),
              child: const Text('J’autorise'),
            ),
          ),
          Positioned(
            left: 120,
            right: 120,
            top: 607,
            child: TextButton(
              onPressed: () async {
                await _finishOnboarding();
              },
              child: const Text('Plus tard', style: TextStyle(color: _ink)),
            ),
          ),
          if (_message.isNotEmpty)
            Positioned(left: 30, right: 30, bottom: 8, child: _messageBox()),
        ],
      ),
    );
  }

  Future<void> _permissionNext() async {
    setState(() => _busy = true);
    try {
      final permission = await SyncService.requestPhotoPermission();
      if (!mounted) return;
      if (permission.hasAccess) {
        setState(() {
          _onboardingStep = 2;
          _message = '';
        });
      } else {
        setState(() => _message = 'Autorisation refusée. Tu pourras l’activer plus tard.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _permissionBullets() {
    const lines = [
      'Toutes les photos et vidéos prises pendant le mariage seront automatiquement envoyées',
      'Seuls les médias pris pendant l’événement seront partagés',
      'Vos photos restent privées ailleurs',
    ];
    return Column(
      children: lines
          .map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.check_circle, color: _red, size: 20),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(text, style: const TextStyle(fontSize: 14.1, height: 1.28)),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _nameStep() {
    return _fitCanvas(
      height: 720,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _cream)),
          const Positioned(
            left: 30,
            right: 30,
            top: 72,
            child: Text(
              'Un dernier détail',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'serif', fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ),
          Positioned(left: 85, right: 85, top: 112, child: _heartDivider(width: 220)),
          const Positioned(
            left: 0,
            right: 0,
            top: 167,
            child: Icon(Icons.person_outline, color: _deepRed, size: 61),
          ),
          const Positioned(
            left: 38,
            right: 38,
            top: 257,
            child: Text(
              'Entrez votre prénom\npour identifier vos médias',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.32),
            ),
          ),
          Positioned(
            left: 34,
            right: 34,
            top: 335,
            child: TextField(
              controller: _nameController,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Votre prénom'),
            ),
          ),
          Positioned(
            left: 34,
            right: 34,
            top: 422,
            child: FilledButton(
              onPressed: _busy ? null : _saveNameAndEnable,
              style: _primaryStyle(),
              child: const Text('Continuer'),
            ),
          ),
          const Positioned(
            left: 20,
            right: 20,
            top: 492,
            child: Text(
              'Vous pourrez le modifier plus tard',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12.5),
            ),
          ),
          if (_message.isNotEmpty)
            Positioned(left: 30, right: 30, top: 535, child: _messageBox()),
        ],
      ),
    );
  }

  Future<void> _saveNameAndEnable() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _message = 'Entre ton prénom pour continuer.');
      return;
    }
    await SyncService.setGuestName(name);
    await _enableAuto(fromOnboarding: true);
  }

  Widget _home() {
    return _fitCanvas(
      height: 690,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _cream)),
          Positioned(left: 35, right: 35, top: 30, child: _coupleHeader()),
          Positioned(top: 172, left: 106, child: _featureIcon(Icons.photo_camera_outlined)),
          Positioned(top: 172, right: 106, child: _featureIcon(Icons.videocam_outlined)),
          const Positioned(
            left: 35,
            right: 35,
            top: 281,
            child: Text(
              'Partagez vos photos\net vidéos',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'serif', fontSize: 29, height: 1.02, fontWeight: FontWeight.w700),
            ),
          ),
          const Positioned(
            left: 44,
            right: 44,
            top: 371,
            child: Text(
              'Capturez chaque instant et\nrevivez ensemble la magie\nde cette journée !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.42),
            ),
          ),
          Positioned(
            left: 34,
            right: 34,
            top: 490,
            child: FilledButton(
              onPressed: _busy ? null : _manualUpload,
              style: _primaryStyle(),
              child: const Text('Déposer mes photos / vidéos'),
            ),
          ),
          Positioned(
            left: 34,
            right: 34,
            top: 555,
            child: OutlinedButton(
              onPressed: () => setState(() => _tab = 1),
              style: _outlineStyle(),
              child: Text(
                _enabled
                    ? 'Voir le partage automatique'
                    : _eveningEnded
                        ? 'Partage terminé'
                        : 'Activer le partage automatique',
              ),
            ),
          ),
          if (_message.isNotEmpty)
            Positioned(left: 30, right: 30, bottom: 5, child: _messageBox()),
        ],
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
    return _fitCanvas(
      height: 690,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _cream)),
          const Positioned(
            left: 30,
            right: 30,
            top: 32,
            child: Text(
              'Partage automatique',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'serif', fontSize: 27, fontWeight: FontWeight.w700),
            ),
          ),
          Positioned(left: 85, right: 85, top: 70, child: _heartDivider(width: 220)),
          const Positioned(left: 111, top: 110, child: _ShareIllustration()),
          const Positioned(
            left: 35,
            right: 35,
            top: 234,
            child: Text(
              'Autorisez l’accès à vos photos\net vidéos',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'serif', fontSize: 21, fontWeight: FontWeight.w700),
            ),
          ),
          Positioned(left: 36, right: 36, top: 315, child: _permissionBullets()),
          Positioned(
            left: 34,
            right: 34,
            top: 539,
            child: FilledButton(
              onPressed: _busy ? null : _enableAuto,
              style: _primaryStyle(),
              child: const Text('J’autorise'),
            ),
          ),
          Positioned(
            left: 120,
            right: 120,
            top: 598,
            child: TextButton(
              onPressed: () => setState(() => _tab = 0),
              child: const Text('Plus tard', style: TextStyle(color: _ink)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeStatus() {
    return _fitCanvas(
      height: 690,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _cream)),
          Positioned(left: 0, right: 0, top: 40, child: _activationIcon()),
          const Positioned(
            left: 34,
            right: 34,
            top: 182,
            child: Text(
              'Partage automatique\nactivé !',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'serif', fontSize: 27, fontWeight: FontWeight.w700, height: 1.05),
            ),
          ),
          const Positioned(
            left: 35,
            right: 35,
            top: 270,
            child: Text(
              'Toutes les photos et vidéos que vous\nprenez pendant le mariage seront\nautomatiquement envoyées.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.7, height: 1.42),
            ),
          ),
          Positioned(
            left: 34,
            right: 34,
            top: 369,
            child: Container(
              padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
              decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(13)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.calendar_month_outlined, color: _ink, size: 24),
                  SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      'Période de partage\n03 juil. 2027 — 14:00\nau 04 juil. 2027 — 05:00',
                      style: TextStyle(fontSize: 13.7, height: 1.45, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 34,
            right: 34,
            top: 498,
            child: OutlinedButton(
              onPressed: _finishEvening,
              style: _outlineStyle(),
              child: const Text('Fin de soirée — arrêter le partage'),
            ),
          ),
          Positioned(
            left: 100,
            right: 100,
            top: 558,
            child: TextButton(
              onPressed: _pauseAuto,
              child: const Text('Mettre en pause', style: TextStyle(color: _ink)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activationIcon() {
    return Center(
      child: SizedBox(
        width: 126,
        height: 104,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(color: _red, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 47),
            ),
            const Positioned(left: 8, top: 8, child: _Dot(color: _gold, size: 7)),
            const Positioned(right: 9, top: 17, child: _Dot(color: _red, size: 5)),
            const Positioned(left: 18, bottom: 14, child: _Dot(color: _red, size: 5)),
            const Positioned(right: 14, bottom: 8, child: _Dot(color: _gold, size: 7)),
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
    return _fitCanvas(
      height: 690,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _cream)),
          const Positioned(
            left: 30,
            right: 30,
            top: 60,
            child: Text(
              'Envoi en cours...',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'serif', fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 132,
            child: Icon(Icons.cloud_upload, color: _red, size: 70),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 212,
            child: Text(
              '$done',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'serif', fontSize: 34, fontWeight: FontWeight.w700),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 254,
            child: Text('médias envoyés', textAlign: TextAlign.center, style: TextStyle(fontSize: 15)),
          ),
          Positioned(
            left: 34,
            right: 34,
            top: 305,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(6),
              color: _red,
              backgroundColor: const Color(0xFFE8D7C7),
            ),
          ),
          Positioned(left: 34, right: 34, top: 350, child: _miniThumbRow()),
          const Positioned(
            left: 36,
            right: 36,
            top: 450,
            child: Text(
              'Les médias sont envoyés en arrière-plan.\nVous pouvez continuer à utiliser votre téléphone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniThumbRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        4,
        (index) => Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: index.isEven ? const Color(0xFFE8D9CA) : const Color(0xFFDCC8B8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.image_outlined, color: _deepRed, size: 28),
        ),
      ),
    );
  }

  Widget _upToDateStatus() {
    return _fitCanvas(
      height: 690,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _cream)),
          Positioned(
            top: 72,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _olive, width: 3),
                ),
                child: const Icon(Icons.check, color: _olive, size: 48),
              ),
            ),
          ),
          const Positioned(
            left: 30,
            right: 30,
            top: 185,
            child: Text(
              'Tout est à jour !',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'serif', fontSize: 29, fontWeight: FontWeight.w700),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 251,
            child: Text(
              '$_sentCount',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'serif', fontSize: 34, fontWeight: FontWeight.w700),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 296,
            child: Text('médias envoyés', textAlign: TextAlign.center, style: TextStyle(fontSize: 15)),
          ),
          Positioned(
            left: 34,
            right: 34,
            top: 365,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 25, 24, 23),
              decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(14)),
              child: const Column(
                children: [
                  Text(
                    'Merci de partager ces beaux\nsouvenirs avec nous !',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, height: 1.35),
                  ),
                  SizedBox(height: 12),
                  Icon(Icons.favorite, color: _red, size: 20),
                ],
              ),
            ),
          ),
          Positioned(
            left: 95,
            right: 95,
            top: 516,
            child: TextButton.icon(
              onPressed: () => _syncNow(),
              icon: const Icon(Icons.refresh, color: _deepRed),
              label: const Text('Actualiser', style: TextStyle(color: _deepRed)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _endedStatus() {
    return _fitCanvas(
      height: 690,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _cream)),
          const Positioned(
            top: 82,
            left: 0,
            right: 0,
            child: Icon(Icons.nights_stay_outlined, color: _deepRed, size: 72),
          ),
          const Positioned(
            left: 30,
            right: 30,
            top: 185,
            child: Text(
              'Fin de soirée',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'serif', fontSize: 29, fontWeight: FontWeight.w700),
            ),
          ),
          const Positioned(
            left: 40,
            right: 40,
            top: 248,
            child: Text(
              'Le partage automatique est arrêté sur ce téléphone.\nLes envois manuels restent disponibles.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, height: 1.45),
            ),
          ),
          Positioned(
            left: 34,
            right: 34,
            top: 375,
            child: OutlinedButton(
              onPressed: () => _enableAuto(resetPersonalEnd: true),
              style: _outlineStyle(),
              child: const Text('Réactiver le partage automatique'),
            ),
          ),
          Positioned(
            left: 34,
            right: 34,
            top: 442,
            child: FilledButton(
              onPressed: _manualUpload,
              style: _primaryStyle(),
              child: const Text('Déposer des photos / vidéos'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gallery() {
    final visible = _recentNames.isEmpty
        ? List<String>.generate(9, (i) => 'Média ${i + 1}')
        : _recentNames.take(9).toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
        children: [
          const Text(
            'Vos derniers envois',
            style: TextStyle(fontFamily: 'serif', fontSize: 27, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visible.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final last = index == 8 && _recentNames.length > 9;
              return Container(
                decoration: BoxDecoration(
                  color: index % 3 == 0
                      ? const Color(0xFFD9C4B1)
                      : index % 3 == 1
                          ? const Color(0xFFE8D9CA)
                          : const Color(0xFFCDBAAA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: last
                      ? Text(
                          '+${_recentNames.length - 8}',
                          style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700),
                        )
                      : const Icon(Icons.image_outlined, color: Colors.white, size: 31),
                ),
              );
            },
          ),
          const SizedBox(height: 19),
          OutlinedButton(
            onPressed: () {},
            style: _outlineStyle(),
            child: const Text('Voir tous les médias'),
          ),
        ],
      ),
    );
  }

  Widget _more() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
        children: [
          const Text(
            'Plus',
            style: TextStyle(fontFamily: 'serif', fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          _settingCard(
            Icons.schedule_outlined,
            'Période automatique',
            '03/07/2027 14:00 → 04/07/2027 05:00',
          ),
          _settingCard(
            Icons.privacy_tip_outlined,
            'Confidentialité',
            'Les envois automatiques restent en attente jusqu’à validation dans l’administration.',
          ),
          if (_enabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton(
                onPressed: _finishEvening,
                style: _outlineStyle(),
                child: const Text('Fin de soirée — arrêter le partage'),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE5D7CC)),
            ),
            child: Column(
              children: [
                const Icon(Icons.favorite_border, color: _deepRed, size: 27),
                const SizedBox(height: 10),
                const Text('Application réalisée par', style: TextStyle(color: Colors.black54, fontSize: 12.5)),
                const SizedBox(height: 4),
                const Text(
                  'Manu D Studio',
                  style: TextStyle(fontFamily: 'serif', fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                const Text('pour', style: TextStyle(color: Colors.black54, fontSize: 12)),
                TextButton(
                  onPressed: _openWebsite,
                  child: const Text(
                    'www.creemachanson.com',
                    style: TextStyle(color: _deepRed, decoration: TextDecoration.underline, fontWeight: FontWeight.w700),
                  ),
                ),
                const Text('© Manu D Studio 2026/2027', style: TextStyle(color: Colors.black45, fontSize: 11.5)),
                const SizedBox(height: 13),
                GestureDetector(
                  onTap: _openWebsite,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      color: const Color(0xFF09172B),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Image.network(
                        'https://mariage.creemachanson.com/assets/img/logo-creemachanson.jpg',
                        width: 245,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'CréeMa Chanson',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingCard(IconData icon, String title, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE5D7CC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _deepRed, size: 23),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(color: Colors.black54, fontSize: 13.2, height: 1.35)),
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
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(10)),
      child: Text(
        _message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.8, fontWeight: FontWeight.w600, height: 1.3),
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
      backgroundColor: Colors.white,
      selectedItemColor: _red,
      unselectedItemColor: const Color(0xFF4D4947),
      selectedFontSize: 11,
      unselectedFontSize: 11,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
        BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), activeIcon: Icon(Icons.check_circle), label: 'Statut'),
        BottomNavigationBarItem(icon: Icon(Icons.photo_library_outlined), activeIcon: Icon(Icons.photo_library), label: 'Galerie'),
        BottomNavigationBarItem(icon: Icon(Icons.more_horiz), activeIcon: Icon(Icons.more_horiz), label: 'Plus'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return Scaffold(backgroundColor: _cream, body: _splash());
    if (!_onboardingDone) {
      return Scaffold(backgroundColor: _cream, body: _onboarding());
    }
    final pages = [_home(), _status(), _gallery(), _more()];
    return Scaffold(
      backgroundColor: _cream,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _bottomNav(),
    );
  }
}

class _ShareIllustration extends StatelessWidget {
  const _ShareIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 96,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 16,
            child: Transform.rotate(
              angle: -.11,
              child: Container(
                width: 51,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8EC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF51493F), width: 1.7),
                ),
                child: const Icon(Icons.image_outlined, color: _gold, size: 28),
              ),
            ),
          ),
          Positioned(
            left: 58,
            top: 4,
            child: Container(
              width: 53,
              height: 82,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF51493F), width: 2),
              ),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 10,
            child: Container(
              width: 68,
              height: 50,
              decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(26)),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 31),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
