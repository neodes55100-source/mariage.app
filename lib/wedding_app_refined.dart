import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';

import 'app_config.dart';
import 'sync_service.dart';
import 'upload_service.dart';

const _red = Color(0xFFB80F24);
const _deepRed = Color(0xFF8E111C);
const _cream = Color(0xFFFFFCF8);
const _soft = Color(0xFFF7EFE7);
const _ink = Color(0xFF27211E);
const _gold = Color(0xFFB5984D);
const _olive = Color(0xFF78823C);

const _floralFrameBase64 = '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';

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
  runApp(const WeddingAppRefined());
}

class WeddingAppRefined extends StatelessWidget {
  const WeddingAppRefined({super.key});

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
          hintStyle: const TextStyle(color: Color(0xFF947F73)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD9BBAA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD9BBAA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _red, width: 1.5),
          ),
        ),
      ),
      home: const WeddingShellRefined(),
    );
  }
}

class WeddingShellRefined extends StatefulWidget {
  const WeddingShellRefined({super.key});

  @override
  State<WeddingShellRefined> createState() => _WeddingShellRefinedState();
}

class _WeddingShellRefinedState extends State<WeddingShellRefined>
    with WidgetsBindingObserver {
  static const _onboardingKey = 'onboarding_done_maquette_v4';
  static const _recentNamesKey = 'recent_upload_names';

  final _nameController = TextEditingController();

  bool _showSplash = true;
  bool _onboardingDone = false;
  bool _busy = true;
  bool _enabled = false;
  bool _manualUploading = false;
  bool _syncing = false;
  bool _allUpToDate = false;
  int _onboardingStep = 0;
  int _tab = 0;
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
    await Future<void>.delayed(const Duration(milliseconds: 1900));
    if (mounted) setState(() => _showSplash = false);
  }

  TextStyle get _scriptStyle => const TextStyle(
        fontFamily: 'cursive',
        fontSize: 31,
        height: 1.02,
        fontWeight: FontWeight.w400,
        color: _deepRed,
      );

  Widget _heartDivider({double width = 220}) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(child: Divider(color: _red.withValues(alpha: .28), height: 1)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.favorite, color: _red, size: 15),
          ),
          Expanded(child: Divider(color: _red.withValues(alpha: .28), height: 1)),
        ],
      ),
    );
  }

  Widget _floralFrame() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Image.memory(
          base64Decode(_floralFrameBase64),
          fit: BoxFit.fill,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  Widget _siteRings({double width = 205}) {
    return Image.network(
      'https://mariage.creemachanson.com/assets/img/rings-design2-final-20260914.png',
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => const SizedBox(height: 115),
    );
  }

  Widget _splash() {
    return ColoredBox(
      color: _cream,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            return Stack(
              children: [
                _floralFrame(),
                Positioned(
                  left: 20,
                  right: 20,
                  top: h * .12,
                  child: Center(child: _siteRings(width: 190)),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  top: h * .34,
                  child: Column(
                    children: [
                      Text(
                        'Emmanuel\n& Jennifer',
                        textAlign: TextAlign.center,
                        style: _scriptStyle.copyWith(fontSize: 40, height: 1.02),
                      ),
                      const SizedBox(height: 10),
                      _heartDivider(width: 190),
                      const SizedBox(height: 10),
                      const Text(
                        'Notre Mariage',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 17,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '03 juillet 2027',
                        style: TextStyle(fontSize: 14.5, color: Colors.black54),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Partagez vos plus beaux\nsouvenirs avec nous',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14.5, height: 1.34),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: h * .07,
                  child: Text(
                    'Merci d’être là !',
                    textAlign: TextAlign.center,
                    style: _scriptStyle.copyWith(fontSize: 28),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _coupleHeader() {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Emmanuel & Jennifer',
            textAlign: TextAlign.center,
            style: _scriptStyle.copyWith(fontSize: 31),
          ),
        ),
        const SizedBox(height: 10),
        _heartDivider(width: 225),
        const SizedBox(height: 10),
        const Text(
          'NOTRE MARIAGE',
          style: TextStyle(
            fontSize: 12.5,
            letterSpacing: 2.6,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
            fontWeight: FontWeight.w700,
            fontSize: 25,
          ),
        ),
        const SizedBox(height: 8),
        _heartDivider(width: 210),
      ],
    );
  }

  ButtonStyle _primaryStyle() => FilledButton.styleFrom(
        backgroundColor: _red,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
      );

  ButtonStyle _outlineStyle() => OutlinedButton.styleFrom(
        foregroundColor: _deepRed,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: _red, width: 1.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
      );

  Widget _cameraVideoIcons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.photo_camera_outlined, size: 58, color: _deepRed),
        SizedBox(width: 42),
        Icon(Icons.videocam_outlined, size: 58, color: _deepRed),
      ],
    );
  }

  Widget _welcomeStep() {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(30, 34, 30, 28),
            children: [
              _coupleHeader(),
              const SizedBox(height: 48),
              _cameraVideoIcons(),
              const SizedBox(height: 33),
              const Text(
                'Partagez vos photos\net vidéos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                  height: 1.03,
                ),
              ),
              const SizedBox(height: 21),
              const Text(
                'Capturez chaque instant et\nrevivez ensemble la magie\nde cette journée !',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.42),
              ),
              const SizedBox(height: 42),
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
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
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
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Les envois manuels sont publiés directement. Le partage automatique n’envoie que les médias pris pendant la période du mariage et ils restent en attente de validation dans l’administration avant d’apparaître dans l’album.',
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

  Widget _permissionIllustration() {
    return SizedBox(
      width: 180,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 12,
            top: 23,
            child: Transform.rotate(
              angle: -.12,
              child: Container(
                width: 52,
                height: 66,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E9),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFF4F473F), width: 1.6),
                ),
                child: const Icon(Icons.image_outlined, color: _gold, size: 29),
              ),
            ),
          ),
          Positioned(
            left: 62,
            top: 9,
            child: Container(
              width: 58,
              height: 89,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF4F473F), width: 2),
              ),
              child: const Center(child: Icon(Icons.favorite, color: _gold, size: 21)),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 8,
            child: Container(
              width: 68,
              height: 50,
              decoration: BoxDecoration(
                color: _red,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 32),
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
            child: Text(text, style: const TextStyle(fontSize: 14.6, height: 1.28)),
          ),
        ],
      ),
    );
  }

  Widget _permissionStep() {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(30, 31, 30, 24),
            children: [
              _pageTitle('Partage automatique'),
              const SizedBox(height: 31),
              Center(child: _permissionIllustration()),
              const SizedBox(height: 20),
              const Text(
                'Autorisez l’accès à vos photos\net vidéos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w700,
                  fontSize: 21,
                  height: 1.14,
                ),
              ),
              const SizedBox(height: 23),
              _checkLine(
                'Toutes les photos et vidéos prises pendant le mariage seront automatiquement envoyées',
              ),
              _checkLine(
                'Seuls les médias pris pendant l’événement seront partagés',
              ),
              _checkLine('Vos photos restent privées ailleurs'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
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
              const SizedBox(height: 5),
              TextButton(
                onPressed: _finishOnboarding,
                child: const Text('Plus tard', style: TextStyle(color: _ink)),
              ),
              _messageBox(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nameStep() {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(30, 54, 30, 24),
            children: [
              _pageTitle('Un dernier détail'),
              const SizedBox(height: 34),
              const Icon(Icons.person_outline, size: 63, color: _deepRed),
              const SizedBox(height: 22),
              const Text(
                'Entrez votre prénom\npour identifier vos médias',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.35),
              ),
              const SizedBox(height: 27),
              TextField(
                controller: _nameController,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Votre prénom'),
              ),
              const SizedBox(height: 27),
              FilledButton(
                onPressed: _busy ? null : _saveNameAndEnable,
                style: _primaryStyle(),
                child: const Text('Continuer'),
              ),
              const SizedBox(height: 13),
              const Text(
                'Vous pourrez le modifier plus tard',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 12.5),
              ),
              _messageBox(),
            ],
          ),
        ),
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
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700),
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

  Future<bool> _confirm(String title, String body, String label) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _cream,
            title: Text(
              title,
              style: const TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700),
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
    bool resetPersonalEnd = false,
    bool skipNameCheck = false,
  }) async {
    final name = skipNameCheck ? _nameController.text.trim() : await _guestName();
    if (name == null || name.length < 2) return;

    if (_eveningEnded && !resetPersonalEnd) {
      final ok = await _confirm(
        'Réactiver le partage automatique ?',
        'Tu avais indiqué que ta soirée était terminée. En réactivant, les nouveaux médias pris pendant la période du mariage pourront de nouveau être envoyés.',
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
      await _syncNow(silent: true);
      if (mounted) {
        setState(() {
          _tab = 1;
          _message = '';
        });
      }
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
      'Le partage automatique va s’arrêter immédiatement sur ce téléphone. Aucun média pris après cette heure ne sera envoyé automatiquement. Les envois manuels resteront disponibles.',
      'Terminer le partage',
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

  Widget _home() {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(30, 30, 30, 24),
            children: [
              _coupleHeader(),
              const SizedBox(height: 44),
              _cameraVideoIcons(),
              const SizedBox(height: 30),
              const Text(
                'Partagez vos photos\net vidéos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.03,
                ),
              ),
              const SizedBox(height: 21),
              const Text(
                'Capturez chaque instant et\nrevivez ensemble la magie\nde cette journée !',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.42),
              ),
              const SizedBox(height: 37),
              FilledButton(
                onPressed: _busy ? null : _manualUpload,
                style: _primaryStyle(),
                child: const Text('Déposer mes photos / vidéos'),
              ),
              const SizedBox(height: 11),
              OutlinedButton(
                onPressed: () {
                  if (_enabled) {
                    setState(() => _tab = 1);
                  } else {
                    _enableAuto();
                  }
                },
                style: _outlineStyle(),
                child: Text(
                  _enabled
                      ? 'Voir le partage automatique'
                      : _eveningEnded
                          ? 'Réactiver le partage automatique'
                          : 'Activer le partage automatique',
                ),
              ),
              _messageBox(),
            ],
          ),
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

  Widget _activeStatus() {
    return _statusPage(
      children: [
        const SizedBox(height: 9),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: _red),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 43),
            ),
            const Positioned(left: 46, top: 2, child: Icon(Icons.auto_awesome, color: _gold, size: 17)),
            const Positioned(right: 44, bottom: 3, child: Icon(Icons.auto_awesome, color: _gold, size: 14)),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Partage automatique\nactivé !',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 27,
            height: 1.05,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Toutes les photos et vidéos que vous\nprenez pendant le mariage seront\nautomatiquement envoyées.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.8, height: 1.38),
        ),
        const SizedBox(height: 25),
        _periodCard(),
        const SizedBox(height: 15),
        OutlinedButton(
          onPressed: _finishEvening,
          style: _outlineStyle(),
          child: const Text('Fin de soirée — arrêter le partage'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _syncing ? null : () => _syncNow(),
          icon: const Icon(Icons.sync, size: 18),
          label: const Text('Synchroniser maintenant'),
        ),
        TextButton(
          onPressed: _pauseAuto,
          child: const Text('Mettre en pause', style: TextStyle(color: Colors.black54)),
        ),
        _messageBox(),
      ],
    );
  }

  Widget _inactiveStatus() {
    return _statusPage(
      children: [
        _pageTitle('Partage automatique'),
        const SizedBox(height: 27),
        _permissionIllustration(),
        const SizedBox(height: 20),
        const Text(
          'Autorisez l’accès à vos photos\net vidéos',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w700,
            fontSize: 21,
          ),
        ),
        const SizedBox(height: 23),
        _checkLine('Seuls les médias pris pendant l’événement sont concernés'),
        _checkLine('Les envois automatiques passent par la validation des mariés'),
        _checkLine('Vous pouvez arrêter le partage à tout moment'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _enableAuto,
          style: _primaryStyle(),
          child: const Text('Activer le partage automatique'),
        ),
        _messageBox(),
      ],
    );
  }

  Widget _sendingStatus() {
    final progress = _uploadTotal == 0 ? 0.35 : _uploadDone / _uploadTotal;
    return _statusPage(
      children: [
        const SizedBox(height: 14),
        const Text(
          'Envoi en cours...',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'serif', fontSize: 27, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 31),
        const Icon(Icons.cloud_upload_rounded, color: _red, size: 70),
        const SizedBox(height: 14),
        Text(
          '${_manualUploading ? _uploadDone : _sentCount}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'serif', fontSize: 38, fontWeight: FontWeight.w700),
        ),
        const Text('médias envoyés', textAlign: TextAlign.center),
        const SizedBox(height: 22),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _manualUploading ? progress.clamp(0.0, 1.0) : null,
            minHeight: 8,
            backgroundColor: const Color(0xFFE6D4C5),
            color: _red,
          ),
        ),
        const SizedBox(height: 29),
        _recentStrip(),
        const SizedBox(height: 18),
        const Text(
          'Les médias sont envoyés en arrière-plan.\nVous pouvez continuer à utiliser votre téléphone.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.8, height: 1.35),
        ),
      ],
    );
  }

  Widget _upToDateStatus() {
    return _statusPage(
      children: [
        const SizedBox(height: 30),
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _olive, width: 3),
          ),
          child: const Icon(Icons.check_rounded, color: _olive, size: 44),
        ),
        const SizedBox(height: 23),
        const Text(
          'Tout est à jour !',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'serif', fontSize: 27, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        Text(
          '$_sentCount',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'serif', fontSize: 39, fontWeight: FontWeight.w700),
        ),
        const Text('médias envoyés', textAlign: TextAlign.center),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            children: [
              Text(
                'Merci de partager ces beaux\nsouvenirs avec nous !',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, height: 1.4),
              ),
              SizedBox(height: 11),
              Icon(Icons.favorite, color: _red, size: 21),
            ],
          ),
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
    return _statusPage(
      children: [
        const SizedBox(height: 42),
        const Icon(Icons.favorite_rounded, color: _deepRed, size: 62),
        const SizedBox(height: 20),
        const Text(
          'Partage terminé',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'serif', fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        const Text(
          'Le partage automatique est arrêté sur ce téléphone.\nLes envois manuels restent disponibles.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.5, height: 1.4),
        ),
        const SizedBox(height: 25),
        OutlinedButton(
          onPressed: () => _enableAuto(resetPersonalEnd: true),
          style: _outlineStyle(),
          child: const Text('Réactiver le partage automatique'),
        ),
      ],
    );
  }

  Widget _statusPage({required List<Widget> children}) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(30, 31, 30, 24),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _periodCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.calendar_month_outlined, color: _ink, size: 25),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Période de partage', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                SizedBox(height: 5),
                Text('03 juil. 2027 — 14:00', style: TextStyle(fontSize: 13)),
                Text('au 04 juil. 2027 — 05:00', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentStrip() {
    final names = _recentNames.take(4).toList();
    if (names.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          4,
          (_) => Container(
            width: 54,
            height: 54,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.photo_outlined, color: _gold),
          ),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: names
          .map(
            (name) => Container(
              width: 54,
              height: 54,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.photo_outlined, color: _deepRed),
            ),
          )
          .toList(),
    );
  }

  Widget _gallery() {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 27, 20, 26),
            children: [
              const Text(
                'Vos derniers envois',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 9,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemBuilder: (context, index) {
                  final extra = _recentNames.length > 9 && index == 8
                      ? '+${_recentNames.length - 8}'
                      : null;
                  return Container(
                    decoration: BoxDecoration(
                      color: index.isEven
                          ? const Color(0xFFF0E2D6)
                          : const Color(0xFFEAD8CC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: extra == null
                          ? const Icon(Icons.photo_outlined, color: _deepRed, size: 32)
                          : Text(
                              extra,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: _deepRed,
                              ),
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 17),
              OutlinedButton(
                onPressed: () {},
                style: _outlineStyle(),
                child: const Text('Voir tous les médias'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openWebsite() async {
    final uri = Uri.parse('https://www.creemachanson.com');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _more() {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 28),
            children: [
              _pageTitle('Plus'),
              const SizedBox(height: 26),
              _settingCard(
                Icons.schedule_outlined,
                'Période automatique',
                '03/07/2027 14:00 → 04/07/2027 05:00',
              ),
              if (_enabled)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: OutlinedButton(
                    onPressed: _finishEvening,
                    style: _outlineStyle(),
                    child: const Text('Fin de soirée — arrêter le partage'),
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 19),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFE5D7CC)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.favorite_border, color: _deepRed, size: 27),
                    const SizedBox(height: 10),
                    const Text(
                      'Application réalisée par',
                      style: TextStyle(color: Colors.black54, fontSize: 12.5),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manu D Studio',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text('pour', style: TextStyle(color: Colors.black54, fontSize: 12)),
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
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
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
        ),
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
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        _message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.35),
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
    if (_showSplash) return Scaffold(body: _splash());
    if (!_onboardingDone) {
      final step = switch (_onboardingStep) {
        0 => _welcomeStep(),
        1 => _permissionStep(),
        _ => _nameStep(),
      };
      return Scaffold(backgroundColor: _cream, body: step);
    }

    final pages = <Widget>[
      _home(),
      _status(),
      _gallery(),
      _more(),
    ];

    return Scaffold(
      backgroundColor: _cream,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _bottomNav(),
    );
  }
}
