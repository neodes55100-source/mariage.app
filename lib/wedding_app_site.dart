import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';

import 'app_config.dart';
import 'sync_service.dart';
import 'upload_service.dart';

const _red = Color(0xFFB50E26);
const _deepRed = Color(0xFF8E111C);
const _cream = Color(0xFFFFFBF7);
const _soft = Color(0xFFF7EFE8);
const _ink = Color(0xFF342725);
const _gold = Color(0xFFC99A3A);
const _olive = Color(0xFF78823C);

const _heroUrl =
    'https://mariage.creemachanson.com/assets/img/couple-hero-design2.jpg';
const _ringsUrl =
    'https://mariage.creemachanson.com/assets/img/rings-design2-final-20260914.png';
const _logoUrl =
    'https://mariage.creemachanson.com/assets/img/logo-creemachanson.jpg';

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
  runApp(const WeddingSiteApp());
}

class WeddingSiteApp extends StatelessWidget {
  const WeddingSiteApp({super.key});

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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          hintStyle: const TextStyle(color: Color(0xFF9B8881)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCC9BF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _red, width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
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
  static const _onboardingKey = 'onboarding_done_site_design_v1';
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
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _showSplash = false);
  }

  TextStyle get _scriptStyle => const TextStyle(
        fontFamily: 'serif',
        fontStyle: FontStyle.italic,
        fontSize: 33,
        height: 1.0,
        fontWeight: FontWeight.w400,
        color: _deepRed,
      );

  ButtonStyle _primaryStyle() => FilledButton.styleFrom(
        backgroundColor: _red,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(31)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      );

  ButtonStyle _outlineStyle() => OutlinedButton.styleFrom(
        foregroundColor: _deepRed,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: _red, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(31)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      );

  Widget _networkImage(
    String url, {
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center,
  }) {
    return Image.network(
      url,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(Icons.favorite, color: _red, size: 38),
      ),
    );
  }

  Widget _heartDivider({double width = 220}) {
    return SizedBox(
      width: width,
      child: const Row(
        children: [
          Expanded(child: Divider(color: Color(0xFFDABBC1), height: 1)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.favorite, color: _red, size: 15),
          ),
          Expanded(child: Divider(color: Color(0xFFDABBC1), height: 1)),
        ],
      ),
    );
  }

  Widget _siteHeader({bool compact = false}) {
    return Column(
      children: [
        if (!compact)
          AspectRatio(
            aspectRatio: 1536 / 971,
            child: _networkImage(
              _heroUrl,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
        Transform.translate(
          offset: Offset(0, compact ? 0 : -2),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: compact ? 8 : 0,
              bottom: compact ? 2 : 0,
            ),
            decoration: const BoxDecoration(color: _cream),
            child: Column(
              children: [
                if (!compact)
                  Transform.translate(
                    offset: const Offset(0, -32),
                    child: SizedBox(
                      width: 205,
                      height: 115,
                      child: _networkImage(_ringsUrl),
                    ),
                  ),
                if (compact)
                  SizedBox(
                    width: 140,
                    height: 76,
                    child: _networkImage(_ringsUrl),
                  ),
                Transform.translate(
                  offset: Offset(0, compact ? 0 : -31),
                  child: Column(
                    children: [
                      Text(
                        'Emmanuel & Jennifer',
                        textAlign: TextAlign.center,
                        style: _scriptStyle.copyWith(fontSize: compact ? 28 : 37),
                      ),
                      const SizedBox(height: 8),
                      _heartDivider(width: compact ? 185 : 220),
                      const SizedBox(height: 8),
                      Text(
                        compact ? 'NOTRE MARIAGE' : '03 juillet 2027',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: compact ? 12 : 15,
                          letterSpacing: compact ? 2.4 : 3.0,
                          fontWeight: compact ? FontWeight.w800 : FontWeight.w500,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _splash() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            _siteHeader(),
            Transform.translate(
              offset: const Offset(0, -14),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: Column(
                  children: [
                    Text(
                      'Notre album photos & vidéos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 30,
                        height: 1.04,
                        fontWeight: FontWeight.w800,
                        color: _deepRed,
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Partagez avec nous les plus beaux souvenirs de cette journée',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeStep() {
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _siteHeader(),
          Transform.translate(
            offset: const Offset(0, -14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 30),
              child: Column(
                children: [
                  const Text(
                    'Partagez vos photos et vidéos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 29,
                      height: 1.04,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Capturez chaque instant et revivez ensemble la magie de cette journée !',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.42),
                  ),
                  const SizedBox(height: 29),
                  FilledButton(
                    onPressed: () => setState(() => _onboardingStep = 1),
                    style: _primaryStyle(),
                    child: const Text('Commencer'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _showInfoDialog,
                    child: const Text(
                      'En savoir plus',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
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

  Future<void> _showInfoDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cream,
        title: const Text(
          'Comment ça marche ?',
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Les envois manuels sont publiés directement. Le partage automatique n’envoie que les médias pris pendant la période du mariage et ils passent par la validation de l’administration avant publication.',
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

  Widget _pageTitle(String title) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w800,
            fontSize: 27,
          ),
        ),
        const SizedBox(height: 8),
        _heartDivider(width: 210),
      ],
    );
  }

  Widget _permissionIllustration() {
    return SizedBox(
      width: 170,
      height: 105,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 12,
            top: 26,
            child: Transform.rotate(
              angle: -.12,
              child: Container(
                width: 51,
                height: 63,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5E8),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _ink, width: 1.4),
                ),
                child: const Icon(Icons.image_outlined, color: _gold, size: 28),
              ),
            ),
          ),
          Positioned(
            left: 60,
            top: 10,
            child: Container(
              width: 58,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _ink, width: 1.6),
              ),
              child: const Center(
                child: Icon(Icons.favorite, color: _gold, size: 19),
              ),
            ),
          ),
          Positioned(
            right: 1,
            bottom: 7,
            child: Container(
              width: 68,
              height: 49,
              decoration: BoxDecoration(
                color: _red,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  color: Colors.white, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.check_circle, color: _red, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 14.7, height: 1.3)),
          ),
        ],
      ),
    );
  }

  Widget _permissionStep() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
        children: [
          _siteHeader(compact: true),
          const SizedBox(height: 14),
          _pageTitle('Partage automatique'),
          const SizedBox(height: 25),
          Center(child: _permissionIllustration()),
          const SizedBox(height: 18),
          const Text(
            'Autorisez l’accès à vos photos et vidéos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.15,
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
          const SizedBox(height: 10),
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
                        setState(() => _message =
                            'Autorisation refusée. Tu pourras l’activer plus tard.');
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            style: _primaryStyle(),
            child: const Text('J’autorise'),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _finishOnboarding,
            child: const Text('Plus tard', style: TextStyle(color: _ink)),
          ),
          _messageBox(),
        ],
      ),
    );
  }

  Widget _nameStep() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(30, 24, 30, 24),
        children: [
          _siteHeader(compact: true),
          const SizedBox(height: 16),
          _pageTitle('Un dernier détail'),
          const SizedBox(height: 28),
          const Icon(Icons.person_outline, size: 60, color: _deepRed),
          const SizedBox(height: 18),
          const Text(
            'Entrez votre prénom pour identifier vos médias',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.35),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Votre prénom'),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : _saveNameAndEnable,
            style: _primaryStyle(),
            child: const Text('Continuer'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Vous pourrez le modifier plus tard',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          _messageBox(),
        ],
      ),
    );
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
          'Votre prénom',
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w800),
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
    return name;
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    String confirmLabel = 'Confirmer',
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _cream,
            title: Text(
              title,
              style: const TextStyle(
                  fontFamily: 'serif', fontWeight: FontWeight.w800),
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
            'Tu avais indiqué que ta soirée était terminée. En réactivant, les nouveaux médias pris pendant la période pourront de nouveau être envoyés.',
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
    final ok = await _confirm(
      title: 'Fin de soirée ?',
      body:
          'Le partage automatique va s’arrêter immédiatement sur ce téléphone. Les envois manuels resteront disponibles.',
      confirmLabel: 'Terminer le partage',
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
      _recentNames = [...uploadedNames.reversed, ..._recentNames]
          .take(12)
          .toList();
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

  Widget _home() {
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _siteHeader(),
          Transform.translate(
            offset: const Offset(0, -15),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Column(
                children: [
                  const Text(
                    'Notre album photos & vidéos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 30,
                      height: 1.02,
                      fontWeight: FontWeight.w800,
                      color: _deepRed,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Partagez avec nous les plus beaux souvenirs de cette journée',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.38),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _busy ? null : _manualUpload,
                    style: _primaryStyle(),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Déposer mes photos / vidéos'),
                  ),
                  const SizedBox(height: 11),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _tab = 1),
                    style: _outlineStyle(),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(
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
          ),
        ],
      ),
    );
  }

  Widget _status() {
    if (_manualUploading || _syncing) return _sendingStatus();
    if (_eveningEnded && !_enabled) return _endedStatus();
    if (!_enabled) return _inactiveStatus();
    if (_allUpToDate) return _upToDateStatus();
    return _activeStatus();
  }

  Widget _statusBase({required List<Widget> children}) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 26),
        children: [
          _siteHeader(compact: true),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _inactiveStatus() {
    return _statusBase(
      children: [
        _pageTitle('Partage automatique'),
        const SizedBox(height: 24),
        Center(child: _permissionIllustration()),
        const SizedBox(height: 17),
        const Text(
          'Activez le partage automatique',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Les médias pris pendant le mariage pourront être envoyés automatiquement en arrière-plan.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _enableAuto,
          style: _primaryStyle(),
          child: const Text('Activer le partage automatique'),
        ),
        _messageBox(),
      ],
    );
  }

  Widget _activeStatus() {
    return _statusBase(
      children: [
        const Icon(Icons.check_circle, color: _red, size: 72),
        const SizedBox(height: 18),
        const Text(
          'Partage automatique activé !',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Toutes les photos et vidéos prises pendant la période du mariage seront envoyées automatiquement.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 22),
        _infoCard(
          Icons.calendar_month_outlined,
          'Période de partage',
          '03 juillet 2027 · 14:00\n04 juillet 2027 · 05:00',
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _finishEvening,
          style: _outlineStyle(),
          child: const Text('Fin de soirée — arrêter le partage'),
        ),
        const SizedBox(height: 9),
        TextButton(
          onPressed: _pauseAuto,
          child: const Text('Mettre en pause', style: TextStyle(color: _ink)),
        ),
      ],
    );
  }

  Widget _sendingStatus() {
    final progress = _uploadTotal > 0 ? _uploadDone / _uploadTotal : null;
    return _statusBase(
      children: [
        _pageTitle('Envoi en cours…'),
        const SizedBox(height: 27),
        const Icon(Icons.cloud_upload_outlined, color: _red, size: 77),
        const SizedBox(height: 17),
        Text(
          '$_sentCount',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 42,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Text(
          'médias envoyés',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15.5),
        ),
        const SizedBox(height: 24),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(10),
          color: _red,
          backgroundColor: const Color(0xFFEBDDDD),
        ),
        const SizedBox(height: 20),
        Text(
          _manualUploading
              ? '$_uploadDone sur $_uploadTotal fichier(s) traité(s)'
              : 'Synchronisation en arrière-plan…',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _upToDateStatus() {
    return _statusBase(
      children: [
        const Icon(Icons.check_circle, color: _olive, size: 78),
        const SizedBox(height: 17),
        const Text(
          'Tout est à jour !',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '$_sentCount média(s) envoyé(s)',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 22),
        _infoCard(
          Icons.favorite_outline,
          'Merci !',
          'Vos souvenirs rejoignent l’album du mariage.',
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _finishEvening,
          style: _outlineStyle(),
          child: const Text('Fin de soirée — arrêter le partage'),
        ),
      ],
    );
  }

  Widget _endedStatus() {
    return _statusBase(
      children: [
        const Icon(Icons.nights_stay_outlined, color: _deepRed, size: 70),
        const SizedBox(height: 16),
        const Text(
          'Partage automatique terminé',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Aucun nouveau média ne sera envoyé automatiquement depuis ce téléphone. Les envois manuels restent disponibles.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : () => _enableAuto(resetPersonalEnd: true),
          style: _primaryStyle(),
          child: const Text('Réactiver le partage'),
        ),
      ],
    );
  }

  Widget _gallery() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
        children: [
          _siteHeader(compact: true),
          const SizedBox(height: 16),
          _pageTitle('Vos derniers envois'),
          const SizedBox(height: 24),
          if (_recentNames.isEmpty)
            _infoCard(
              Icons.photo_library_outlined,
              'Aucun envoi récent',
              'Les derniers fichiers envoyés depuis ce téléphone apparaîtront ici.',
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentNames.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
              ),
              itemBuilder: (context, index) {
                final name = _recentNames[index];
                final isVideo = name.toLowerCase().endsWith('.mp4') ||
                    name.toLowerCase().endsWith('.mov') ||
                    name.toLowerCase().endsWith('.m4v');
                return Container(
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xFFE7D9D1)),
                  ),
                  child: Center(
                    child: Icon(
                      isVideo
                          ? Icons.videocam_outlined
                          : Icons.photo_outlined,
                      color: _deepRed,
                      size: 34,
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () async {
              final uri = Uri.parse('${AppConfig.siteBaseUrl}/album.php');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
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
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
        children: [
          _siteHeader(compact: true),
          const SizedBox(height: 16),
          _pageTitle('Plus'),
          const SizedBox(height: 22),
          _infoCard(
            Icons.lock_outline,
            'Vie privée',
            'Le partage automatique ne sélectionne que les médias pris pendant la période définie du mariage.',
          ),
          const SizedBox(height: 11),
          _infoCard(
            Icons.schedule_outlined,
            'Période automatique',
            '03/07/2027 14:00 → 04/07/2027 05:00',
          ),
          if (_enabled) ...[
            const SizedBox(height: 11),
            OutlinedButton(
              onPressed: _finishEvening,
              style: _outlineStyle(),
              child: const Text('Fin de soirée — arrêter le partage'),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE4D5CD)),
            ),
            child: Column(
              children: [
                const Icon(Icons.favorite_border, color: _deepRed, size: 28),
                const SizedBox(height: 9),
                const Text(
                  'Application réalisée par',
                  style: TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manu D Studio',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('pour',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                TextButton(
                  onPressed: _openWebsite,
                  child: const Text(
                    'www.creemachanson.com',
                    style: TextStyle(
                      color: _deepRed,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Text(
                  '© Manu D Studio 2026/2027',
                  style: TextStyle(fontSize: 11.5, color: Colors.black45),
                ),
                const SizedBox(height: 13),
                GestureDetector(
                  onTap: _openWebsite,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.black,
                      padding: const EdgeInsets.all(10),
                      child: SizedBox(
                        height: 95,
                        child: _networkImage(_logoUrl),
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

  Widget _infoCard(IconData icon, String title, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6D8D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _deepRed, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(text,
                    style: const TextStyle(
                        fontSize: 13.5, height: 1.35, color: Colors.black54)),
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
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _openWebsite() async {
    final uri = Uri.parse('https://www.creemachanson.com');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      unselectedItemColor: const Color(0xFF514D4B),
      selectedFontSize: 11,
      unselectedFontSize: 11,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
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
    if (_showSplash) {
      return Scaffold(backgroundColor: _cream, body: _splash());
    }

    if (!_onboardingDone) {
      final page = switch (_onboardingStep) {
        0 => _welcomeStep(),
        1 => _permissionStep(),
        _ => _nameStep(),
      };
      return Scaffold(backgroundColor: _cream, body: page);
    }

    final pages = [_home(), _status(), _gallery(), _more()];
    return Scaffold(
      backgroundColor: _cream,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _bottomNav(),
    );
  }
}
