import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';

import 'app_config.dart';
import 'design_assets.dart';
import 'sync_service.dart';
import 'upload_service.dart';

const _red = Color(0xFFB91322);
const _deepRed = Color(0xFF8E111C);
const _gold = Color(0xFFB79A55);
const _cream = Color(0xFFFFFCF8);
const _soft = Color(0xFFF6EEE5);
const _ink = Color(0xFF241F1C);
const _olive = Color(0xFF78823C);
const _ringsUrl = 'https://mariage.creemachanson.com/assets/img/rings-design2-final-20260914.png';
const _brandLogoUrl = 'https://mariage.creemachanson.com/assets/img/logo-creemachanson.jpg';

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
  runApp(const WeddingAppV3());
}

class WeddingAppV3 extends StatelessWidget {
  const WeddingAppV3({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mariage Emmanuel & Jennifer',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _cream,
        colorScheme: ColorScheme.fromSeed(seedColor: _red),
        textTheme: ThemeData.light().textTheme.apply(bodyColor: _ink, displayColor: _ink),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCC7B6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCC7B6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _red, width: 1.5),
          ),
        ),
      ),
      home: const WeddingShellV3(),
    );
  }
}

class WeddingShellV3 extends StatefulWidget {
  const WeddingShellV3({super.key});

  @override
  State<WeddingShellV3> createState() => _WeddingShellV3State();
}

class _WeddingShellV3State extends State<WeddingShellV3> with WidgetsBindingObserver {
  static const _onboardingKey = 'onboarding_done_maquette_v5';
  static const _recentNamesKey = 'recent_upload_names';

  final _nameController = TextEditingController();
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
    if (state == AppLifecycleState.resumed && _enabled) _syncNow(silent: true);
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
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (mounted) setState(() => _showSplash = false);
  }

  TextStyle get _script => const TextStyle(
        fontFamily: 'serif',
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        color: _deepRed,
      );

  ButtonStyle get _primary => FilledButton.styleFrom(
        backgroundColor: _red,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      );

  ButtonStyle get _outline => OutlinedButton.styleFrom(
        foregroundColor: _deepRed,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: _red, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
      );

  Widget _divider([double width = 230]) => SizedBox(
        width: width,
        child: Row(
          children: [
            Expanded(child: Divider(color: _red.withValues(alpha: .25))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.favorite, color: _red, size: 15),
            ),
            Expanded(child: Divider(color: _red.withValues(alpha: .25))),
          ],
        ),
      );

  Widget _rings([double width = 220]) => SizedBox(
        width: width,
        height: width * .57,
        child: Image.network(
          _ringsUrl,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );

  Widget _flowers({bool bottom = false}) => IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              left: -12,
              top: -4,
              child: Image.memory(WeddingDesignAssets.roseTopLeft, width: 155, fit: BoxFit.contain),
            ),
            Positioned(
              right: -8,
              top: -4,
              child: Image.memory(WeddingDesignAssets.roseTopRight, width: 130, fit: BoxFit.contain),
            ),
            if (bottom)
              Positioned(
                left: -4,
                bottom: 0,
                child: Image.memory(WeddingDesignAssets.roseBottomLeft, width: 94, fit: BoxFit.contain),
              ),
            if (bottom)
              Positioned(
                right: -2,
                bottom: 0,
                child: Image.memory(WeddingDesignAssets.roseBottomRight, width: 76, fit: BoxFit.contain),
              ),
            if (bottom)
              Positioned(
                left: 65,
                bottom: 78,
                child: Image.memory(WeddingDesignAssets.petalBottomLeft, width: 54, fit: BoxFit.contain),
              ),
          ],
        ),
      );

  Widget _decorated(Widget child, {bool bottom = false}) => Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _cream)),
          Positioned.fill(child: _flowers(bottom: bottom)),
          child,
        ],
      );

  Widget _header() => Column(
        children: [
          Text('Emmanuel & Jennifer', textAlign: TextAlign.center, style: _script.copyWith(fontSize: 36)),
          const SizedBox(height: 10),
          _divider(245),
          const SizedBox(height: 8),
          const Text(
            'NOTRE MARIAGE',
            style: TextStyle(fontSize: 13, letterSpacing: 2.7, fontWeight: FontWeight.w800),
          ),
        ],
      );

  Widget _title(String text) => Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'serif', fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _divider(220),
        ],
      );

  Widget _splash() => Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _cream)),
          Positioned.fill(child: _flowers(bottom: true)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final h = c.maxHeight;
                return Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(top: h * .11, left: 20, right: 20, child: Center(child: _rings(240))),
                    Positioned(
                      top: h * .315,
                      left: 20,
                      right: 20,
                      child: Text('Emmanuel & Jennifer', textAlign: TextAlign.center, style: _script.copyWith(fontSize: 42)),
                    ),
                    Positioned(top: h * .39, left: 0, right: 0, child: Center(child: _divider(220))),
                    Positioned(
                      top: h * .445,
                      left: 20,
                      right: 20,
                      child: const Column(
                        children: [
                          Text('Notre Mariage', style: TextStyle(fontFamily: 'serif', fontSize: 22, fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          Text('03 juillet 2027', style: TextStyle(fontSize: 16, color: Colors.black54)),
                        ],
                      ),
                    ),
                    Positioned(
                      top: h * .58,
                      left: 34,
                      right: 34,
                      child: const Text(
                        'Partagez vos plus beaux\nsouvenirs avec nous',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17, height: 1.35),
                      ),
                    ),
                    Positioned(
                      bottom: h * .055,
                      left: 24,
                      right: 24,
                      child: Text('Merci d’être là !', textAlign: TextAlign.center, style: _script.copyWith(fontSize: 31)),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );

  Widget _feature(IconData icon) => Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          color: _cream.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _deepRed, width: 1.8),
        ),
        child: Icon(icon, color: _deepRed, size: 44),
      );

  Widget _welcome() => _decorated(
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(30, 42, 30, 28),
            children: [
              _header(),
              const SizedBox(height: 34),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_feature(Icons.photo_camera_outlined), const SizedBox(width: 28), _feature(Icons.videocam_outlined)],
              ),
              const SizedBox(height: 34),
              const Text(
                'Partagez vos photos\net vidéos',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'serif', fontSize: 31, height: 1.05, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 22),
              const Text(
                'Capturez chaque instant et\nrevivez ensemble la magie\nde cette journée !',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, height: 1.42),
              ),
              const SizedBox(height: 36),
              FilledButton(onPressed: () => setState(() => _onboardingStep = 1), style: _primary, child: const Text('Commencer')),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _showInfo,
                child: const Text('En savoir plus', style: TextStyle(color: _ink, decoration: TextDecoration.underline, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );

  Future<void> _showInfo() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cream,
        title: const Text('Comment ça marche ?', style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w800)),
        content: const Text(
          'Les envois manuels sont publiés directement. Le partage automatique envoie uniquement les médias pris pendant le mariage et ceux-ci passent par la validation des administrateurs.',
          style: TextStyle(height: 1.45),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), style: FilledButton.styleFrom(backgroundColor: _red), child: const Text('Compris'))],
      ),
    );
  }

  Widget _shareIllustration() => SizedBox(
        width: 180,
        height: 110,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 12,
              top: 18,
              child: Transform.rotate(
                angle: -.12,
                child: Container(
                  width: 56,
                  height: 70,
                  decoration: BoxDecoration(color: const Color(0xFFFFF7EB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF51493F), width: 1.7)),
                  child: const Icon(Icons.image_outlined, color: _gold, size: 31),
                ),
              ),
            ),
            Positioned(
              left: 63,
              top: 5,
              child: Container(
                width: 58,
                height: 91,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF51493F), width: 2)),
              ),
            ),
            Positioned(
              right: 3,
              bottom: 10,
              child: Container(
                width: 73,
                height: 53,
                decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(27)),
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 34),
              ),
            ),
          ],
        ),
      );

  Widget _check(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.check_circle, color: _red, size: 22)),
            const SizedBox(width: 11),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.32))),
          ],
        ),
      );

  Widget _permission() => _decorated(
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(30, 44, 30, 28),
            children: [
              _title('Partage automatique'),
              const SizedBox(height: 32),
              Center(child: _shareIllustration()),
              const SizedBox(height: 26),
              const Text('Autorisez l’accès à vos photos\net vidéos', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'serif', fontSize: 23, fontWeight: FontWeight.w800)),
              const SizedBox(height: 28),
              _check('Toutes les photos et vidéos prises pendant le mariage seront automatiquement envoyées'),
              _check('Seuls les médias pris pendant l’événement seront partagés'),
              _check('Vos photos restent privées ailleurs'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _requestPermission,
                style: _primary,
                child: const Text('J’autorise'),
              ),
              const SizedBox(height: 6),
              TextButton(onPressed: _finishOnboarding, child: const Text('Plus tard', style: TextStyle(color: _ink))),
              _messageBox(),
            ],
          ),
        ),
      );

  Future<void> _requestPermission() async {
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
        setState(() => _message = 'Autorisation refusée. Vous pourrez l’activer plus tard.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _nameStep() => _decorated(
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(30, 70, 30, 28),
            children: [
              _title('Un dernier détail'),
              const SizedBox(height: 34),
              const Icon(Icons.person_outline, size: 68, color: _deepRed),
              const SizedBox(height: 22),
              const Text('Entrez votre prénom\npour identifier vos médias', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, height: 1.35)),
              const SizedBox(height: 28),
              TextField(controller: _nameController, enabled: !_busy, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Votre prénom')),
              const SizedBox(height: 24),
              FilledButton(onPressed: _busy ? null : _saveNameAndEnable, style: _primary, child: const Text('Continuer')),
              const SizedBox(height: 12),
              const Text('Vous pourrez le modifier plus tard', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12.5)),
              _messageBox(),
            ],
          ),
        ),
      );

  Widget _onboarding() => switch (_onboardingStep) { 0 => _welcome(), 1 => _permission(), _ => _nameStep() };

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

  Future<void> _saveNameAndEnable() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _message = 'Entrez votre prénom pour continuer.');
      return;
    }
    await SyncService.setGuestName(name);
    await _finishOnboarding();
    await _enableAuto(skipNameCheck: true);
  }

  Widget _home() => _decorated(
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(30, 42, 30, 38),
            children: [
              _header(),
              const SizedBox(height: 22),
              Center(child: _rings(165)),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [_feature(Icons.photo_camera_outlined), const SizedBox(width: 28), _feature(Icons.videocam_outlined)]),
              const SizedBox(height: 28),
              const Text('Partagez vos photos\net vidéos', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'serif', fontSize: 30, height: 1.04, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              const Text('Capturez chaque instant et\nrevivez ensemble la magie\nde cette journée !', textAlign: TextAlign.center, style: TextStyle(fontSize: 16.5, height: 1.42)),
              const SizedBox(height: 30),
              FilledButton(onPressed: _busy ? null : _manualUpload, style: _primary, child: const Text('Déposer mes photos / vidéos')),
              const SizedBox(height: 11),
              OutlinedButton(
                onPressed: () => setState(() => _tab = 1),
                style: _outline,
                child: Text(_enabled ? 'Voir le partage automatique' : _eveningEnded ? 'Partage terminé' : 'Activer le partage automatique'),
              ),
              _messageBox(),
            ],
          ),
        ),
        bottom: true,
      );

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
        title: const Text('Un dernier détail', style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w800)),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Votre prénom')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: _ink))),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 2) Navigator.pop(context, value);
            },
            style: FilledButton.styleFrom(backgroundColor: _red),
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
    return name;
  }

  Future<bool> _confirm(String title, String body) async => await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _cream,
          title: Text(title, style: const TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w800)),
          content: Text(body, style: const TextStyle(height: 1.4)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler', style: TextStyle(color: _ink))),
            FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: _red), child: const Text('Confirmer')),
          ],
        ),
      ) ?? false;

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
    if (Platform.isAndroid) await Workmanager().cancelByUniqueName(AppConfig.backgroundUniqueName);
  }

  Future<void> _enableAuto({bool resetPersonalEnd = false, bool skipNameCheck = false}) async {
    final name = skipNameCheck ? _nameController.text.trim() : await _guestName();
    if (name == null || name.length < 2) return;
    if (_eveningEnded && !resetPersonalEnd) {
      final ok = await _confirm('Réactiver le partage automatique ?', 'La fin de soirée a déjà été enregistrée sur ce téléphone. Confirmer réactivera le partage automatique.');
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
        setState(() => _message = 'L’accès aux photos et vidéos est nécessaire pour le partage automatique.');
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
      await _syncNow(silent: true);
      if (mounted) setState(() => _tab = 1);
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
    final ok = await _confirm('Fin de soirée ?', 'Le partage automatique s’arrêtera immédiatement sur ce téléphone. Les envois manuels resteront disponibles.');
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
      _message = '';
      _tab = 1;
    });
  }

  Future<void> _syncNow({bool silent = false}) async {
    if (!_enabled) return;
    if (!silent && mounted) setState(() { _syncing = true; _allUpToDate = false; _message = ''; });
    try {
      final report = await SyncService.sync();
      _sentCount = await SyncService.sentCount();
      if (!silent && mounted) {
        setState(() {
          _allUpToDate = true;
          _message = report.uploaded > 0 ? '${report.uploaded} nouveau(x) média(s) envoyé(s).' : 'Tout est à jour !';
        });
      }
    } catch (e) {
      if (!silent && mounted) setState(() => _message = 'Synchronisation impossible : $e');
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
    final picked = await FilePicker.platform.pickFiles(type: FileType.media, allowMultiple: true, withData: false);
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
      _recentNames = [...names.reversed, ..._recentNames].take(12).toList();
      await prefs.setStringList(_recentNamesKey, _recentNames);
    }
    if (!mounted) return;
    setState(() {
      _manualUploading = false;
      _allUpToDate = failed == 0;
      _message = failed == 0 ? '$uploaded média(s) envoyé(s) avec succès.' : '$uploaded envoyé(s), $failed échec(s).';
    });
  }

  Widget _status() {
    if (_manualUploading || _syncing) return _sending();
    if (_eveningEnded && !_enabled) return _ended();
    if (_allUpToDate && _enabled) return _upToDate();
    if (!_enabled) return _inactive();
    return _active();
  }

  Widget _statusPage(List<Widget> children) => _decorated(
        SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(30, 44, 30, 34), children: children)),
      );

  Widget _inactive() => _statusPage([
        _title('Partage automatique'),
        const SizedBox(height: 32),
        Center(child: _shareIllustration()),
        const SizedBox(height: 25),
        const Text('Autorisez l’accès à vos photos\net vidéos', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'serif', fontSize: 23, fontWeight: FontWeight.w800)),
        const SizedBox(height: 28),
        _check('Toutes les photos et vidéos prises pendant le mariage seront automatiquement envoyées'),
        _check('Seuls les médias pris pendant l’événement seront partagés'),
        _check('Vos photos restent privées ailleurs'),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _enableAuto, style: _primary, child: const Text('Activer le partage automatique')),
        _messageBox(),
      ]);

  Widget _badge(Color color) => Center(
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .13), border: Border.all(color: color, width: 2)),
          child: Icon(Icons.check_rounded, color: color, size: 56),
        ),
      );

  Widget _periodCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(18)),
        child: const Row(
          children: [
            Icon(Icons.calendar_month_outlined, color: _deepRed, size: 28),
            SizedBox(width: 14),
            Expanded(child: Text('Période de partage\n03 juillet 2027 — 14:00\nau 04 juillet 2027 — 05:00', style: TextStyle(height: 1.38, fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Widget _active() => _statusPage([
        const SizedBox(height: 16),
        _badge(_red),
        const SizedBox(height: 24),
        const Text('Partage automatique\nactivé !', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'serif', fontSize: 29, height: 1.05, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        const Text('Toutes les photos et vidéos que vous prenez pendant le mariage seront automatiquement envoyées.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15.5, height: 1.4)),
        const SizedBox(height: 24),
        _periodCard(),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: _syncing ? null : () => _syncNow(), style: _primary, icon: const Icon(Icons.sync), label: const Text('Synchroniser maintenant')),
        const SizedBox(height: 11),
        OutlinedButton(onPressed: _pauseAuto, style: _outline, child: const Text('Mettre en pause')),
        const SizedBox(height: 11),
        OutlinedButton(onPressed: _finishEvening, style: _outline, child: const Text('Fin de soirée — arrêter le partage')),
        _messageBox(),
      ]);

  Widget _sending() {
    final total = _uploadTotal > 0 ? _uploadTotal : 1;
    final progress = (_uploadDone / total).clamp(0.0, 1.0).toDouble();
    return _statusPage([
      _title('Envoi en cours…'),
      const SizedBox(height: 36),
      const Icon(Icons.cloud_upload_outlined, size: 74, color: _deepRed),
      const SizedBox(height: 18),
      Text('$_sentCount', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'serif', fontSize: 48, fontWeight: FontWeight.w800)),
      const Text('médias envoyés', textAlign: TextAlign.center, style: TextStyle(fontSize: 15.5, color: Colors.black54)),
      const SizedBox(height: 28),
      LinearProgressIndicator(value: _manualUploading ? progress : null, minHeight: 9, borderRadius: BorderRadius.circular(10), color: _red, backgroundColor: const Color(0xFFEEDDD9)),
      const SizedBox(height: 22),
      Text(_manualUploading ? '$_uploadDone / $_uploadTotal média(s) traité(s)' : 'Les médias sont envoyés en arrière-plan.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, height: 1.4)),
    ]);
  }

  Widget _upToDate() => _statusPage([
        const SizedBox(height: 20),
        _badge(_olive),
        const SizedBox(height: 24),
        const Text('Tout est à jour !', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'serif', fontSize: 31, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        Text('$_sentCount média(s) envoyé(s)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(18)),
          child: const Text('♥\nMerci de partager ces souvenirs avec nous.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15.5, height: 1.5, color: _deepRed)),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(onPressed: () => _syncNow(), style: _primary, icon: const Icon(Icons.sync), label: const Text('Vérifier à nouveau')),
        const SizedBox(height: 11),
        OutlinedButton(onPressed: _finishEvening, style: _outline, child: const Text('Fin de soirée — arrêter le partage')),
      ]);

  Widget _ended() => _statusPage([
        const SizedBox(height: 20),
        _badge(_gold),
        const SizedBox(height: 24),
        const Text('Partage terminé', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'serif', fontSize: 31, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        const Text('Le partage automatique est arrêté sur ce téléphone. Les envois manuels restent disponibles.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15.5, height: 1.4)),
        const SizedBox(height: 24),
        OutlinedButton(onPressed: () => _enableAuto(resetPersonalEnd: true), style: _outline, child: const Text('Réactiver le partage automatique')),
      ]);

  Widget _gallery() => _decorated(
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 38, 24, 34),
            children: [
              _title('Vos derniers envois'),
              const SizedBox(height: 28),
              if (_recentNames.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .94), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5D7CC))),
                  child: const Column(children: [Icon(Icons.photo_library_outlined, size: 54, color: _deepRed), SizedBox(height: 14), Text('Vos derniers envois apparaîtront ici.', textAlign: TextAlign.center)]),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentNames.length > 9 ? 9 : _recentNames.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemBuilder: (context, index) => Container(
                    decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5D7CC))),
                    child: Tooltip(message: _recentNames[index], child: const Icon(Icons.image_outlined, color: _deepRed, size: 34)),
                  ),
                ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () async => launchUrl(Uri.parse('${AppConfig.siteBaseUrl}/album.php'), mode: LaunchMode.externalApplication),
                style: _outline,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Voir tous les médias'),
              ),
            ],
          ),
        ),
      );

  Widget _setting(IconData icon, String title, String text) => Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .94), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE5D7CC))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: _deepRed), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(text, style: const TextStyle(color: Colors.black54, height: 1.35))]))]),
      );

  Widget _more() => _decorated(
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(26, 38, 26, 34),
            children: [
              _title('Plus'),
              const SizedBox(height: 26),
              _setting(Icons.lock_outline, 'Confidentialité', 'Le partage automatique ne sélectionne que les médias pris pendant la période du mariage.'),
              _setting(Icons.schedule_outlined, 'Période automatique', '03/07/2027 14:00 → 04/07/2027 05:00'),
              if (_enabled) Padding(padding: const EdgeInsets.only(bottom: 12), child: OutlinedButton(onPressed: _finishEvening, style: _outline, child: const Text('Fin de soirée — arrêter le partage'))),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .94), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5D7CC))),
                child: Column(
                  children: [
                    const Icon(Icons.favorite_border, color: _deepRed, size: 28),
                    const SizedBox(height: 10),
                    const Text('Application réalisée par', style: TextStyle(color: Colors.black54, fontSize: 12.5)),
                    const SizedBox(height: 4),
                    const Text('Manu D Studio', style: TextStyle(fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    const Text('pour', style: TextStyle(color: Colors.black54, fontSize: 12)),
                    TextButton(onPressed: _openWebsite, child: const Text('www.creemachanson.com', style: TextStyle(color: _deepRed, decoration: TextDecoration.underline, fontWeight: FontWeight.w800))),
                    const Text('© Manu D Studio 2026/2027', style: TextStyle(color: Colors.black45, fontSize: 11.5)),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _openWebsite,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: const Color(0xFF09172B),
                          padding: const EdgeInsets.all(8),
                          child: Image.network(_brandLogoUrl, width: 245, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(12), child: Text('CréeMa Chanson', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _openWebsite() async => launchUrl(Uri.parse('https://www.creemachanson.com'), mode: LaunchMode.externalApplication);

  Widget _messageBox() {
    if (_message.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(12)),
      child: Text(_message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.35)),
    );
  }

  Widget _bottomNav() => BottomNavigationBar(
        currentIndex: _tab,
        onTap: (value) => setState(() {
          _tab = value;
          if (value != 1) _allUpToDate = false;
        }),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: _red,
        unselectedItemColor: const Color(0xFF4C4947),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), activeIcon: Icon(Icons.check_circle), label: 'Statut'),
          BottomNavigationBarItem(icon: Icon(Icons.photo_library_outlined), activeIcon: Icon(Icons.photo_library), label: 'Galerie'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'Plus'),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return Scaffold(body: _splash());
    if (!_onboardingDone) return Scaffold(backgroundColor: _cream, body: _onboarding());
    final pages = [_home(), _status(), _gallery(), _more()];
    return Scaffold(
      backgroundColor: _cream,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _bottomNav(),
    );
  }
}
