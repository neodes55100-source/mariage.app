import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';

import 'app_config.dart';
import 'sync_service.dart';
import 'upload_service.dart';

const _red = Color(0xFFB91322);
const _deepRed = Color(0xFF8E111C);
const _gold = Color(0xFFB79A55);
const _cream = Color(0xFFFFFCF8);
const _soft = Color(0xFFF6EEE5);
const _ink = Color(0xFF241F1C);
const _olive = Color(0xFF78823C);

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
          contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
          hintStyle: const TextStyle(color: Colors.black38),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDCC7B6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDCC7B6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _red, width: 1.4),
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

class _WeddingShellState extends State<WeddingShell> with WidgetsBindingObserver {
  static const _onboardingKey = 'onboarding_done_maquette_v3';
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
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700, color: _ink),
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
  }) async {
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

  Future<void> _enableAuto({bool resetPersonalEnd = false, bool skipNameCheck = false}) async {
    final name = skipNameCheck ? _nameController.text.trim() : await _guestName();
    if (name == null || name.length < 2) return;
    if (_eveningEnded && !resetPersonalEnd) {
      final ok = await _confirm(
        title: 'Réactiver le partage automatique ?',
        body:
            'Tu avais indiqué que ta soirée était terminée. En réactivant, les nouveaux médias pris jusqu’à la fin de la période pourront de nouveau être envoyés.',
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
    final ok = await _confirm(
      title: 'Fin de soirée ?',
      body:
          'Le partage automatique va s’arrêter immédiatement sur ce téléphone. Aucun média pris après cette heure ne sera envoyé automatiquement. Les envois manuels resteront disponibles.',
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

  String _clock(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  String _dateTimeLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à ${_clock(d)}';

  TextStyle get _scriptStyle => const TextStyle(
        fontFamily: 'serif',
        fontStyle: FontStyle.italic,
        fontSize: 32,
        height: 1.02,
        fontWeight: FontWeight.w400,
        color: _deepRed,
      );

  Widget _heartDivider({double width = 225}) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(child: Divider(color: _red.withValues(alpha: .26), height: 1)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 9),
            child: Icon(Icons.favorite, color: _red, size: 14),
          ),
          Expanded(child: Divider(color: _red.withValues(alpha: .26), height: 1)),
        ],
      ),
    );
  }

  Widget _coupleHeader() {
    return Column(
      children: [
        Text('Emmanuel & Jennifer', textAlign: TextAlign.center, style: _scriptStyle),
        const SizedBox(height: 9),
        _heartDivider(width: 225),
        const SizedBox(height: 7),
        const Text(
          'NOTRE MARIAGE',
          style: TextStyle(fontSize: 12, letterSpacing: 2.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _pageTitle(String text) {
    return Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 27,
            fontWeight: FontWeight.w700,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 9),
        _heartDivider(width: 220),
      ],
    );
  }

  ButtonStyle _primaryStyle() {
    return FilledButton.styleFrom(
      backgroundColor: _red,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(51),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
    );
  }

  ButtonStyle _outlineStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _deepRed,
      minimumSize: const Size.fromHeight(49),
      side: const BorderSide(color: _red, width: 1.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
      textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
    );
  }

  Widget _featureIcon(IconData icon) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Center(child: Icon(icon, size: 53, color: _deepRed)),
    );
  }

  Widget _splash() {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: _cream)),
        const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _RoseFramePainter()))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 35, 30, 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const _RingsIllustration(size: 108),
                const SizedBox(height: 24),
                Text(
                  'Emmanuel\n& Jennifer',
                  textAlign: TextAlign.center,
                  style: _scriptStyle.copyWith(fontSize: 40, height: 1.04),
                ),
                const SizedBox(height: 14),
                _heartDivider(width: 200),
                const SizedBox(height: 12),
                const Text(
                  'Notre Mariage',
                  style: TextStyle(fontFamily: 'serif', letterSpacing: 1.3, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text('03 juillet 2027', style: TextStyle(fontSize: 14.5, color: Colors.black54)),
                const SizedBox(height: 28),
                const Text(
                  'Partagez vos plus beaux\nsouvenirs avec nous',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.5, height: 1.35),
                ),
                const Spacer(flex: 3),
                Text('Merci d’être là !', style: _scriptStyle.copyWith(fontSize: 27)),
              ],
            ),
          ),
        ),
      ],
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
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(30, 34, 30, 28),
        children: [
          _coupleHeader(),
          const SizedBox(height: 39),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _featureIcon(Icons.photo_camera_outlined),
              const SizedBox(width: 20),
              _featureIcon(Icons.videocam_outlined),
            ],
          ),
          const SizedBox(height: 25),
          const Text(
            'Partagez vos photos\net vidéos',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700, fontSize: 27, height: 1.05),
          ),
          const SizedBox(height: 19),
          const Text(
            'Capturez chaque instant et\nrevivez ensemble la magie\nde cette journée !',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15.5, height: 1.4),
          ),
          const SizedBox(height: 37),
          FilledButton(
            onPressed: () => setState(() => _onboardingStep = 1),
            style: _primaryStyle(),
            child: const Text('Commencer'),
          ),
          const SizedBox(height: 7),
          TextButton(
            onPressed: _showInfoDialog,
            child: const Text(
              'En savoir plus',
              style: TextStyle(color: _ink, decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
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
        title: const Text('Comment ça marche ?', style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700)),
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
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(30, 31, 30, 24),
        children: [
          _pageTitle('Partage automatique'),
          const SizedBox(height: 29),
          const Center(child: _ShareIllustration()),
          const SizedBox(height: 24),
          const Text(
            'Autorisez l’accès à vos photos\net vidéos',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700, fontSize: 20.5, height: 1.15),
          ),
          const SizedBox(height: 22),
          _checkLine('Toutes les photos et vidéos prises pendant le mariage seront automatiquement envoyées'),
          _checkLine('Seuls les médias pris pendant l’événement seront partagés'),
          _checkLine('Vos photos restent privées ailleurs'),
          const SizedBox(height: 14),
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
                        setState(() => _message = 'Autorisation refusée. Tu pourras l’activer plus tard.');
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
            onPressed: () async {
              await _finishOnboarding();
              if (mounted) setState(() => _tab = 0);
            },
            child: const Text('Plus tard', style: TextStyle(color: _ink)),
          ),
          _messageBox(),
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
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14.7, height: 1.28))),
        ],
      ),
    );
  }

  Widget _nameStep() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(30, 55, 30, 24),
        children: [
          _pageTitle('Un dernier détail'),
          const SizedBox(height: 30),
          const Icon(Icons.person_outline, size: 61, color: _deepRed),
          const SizedBox(height: 21),
          const Text(
            'Entrez votre prénom\npour identifier vos médias',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15.8, height: 1.3),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Votre prénom'),
            onChanged: (_) {
              if (_message.isNotEmpty) setState(() => _message = '');
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _saveNameAndEnable,
            style: _primaryStyle(),
            child: const Text('Continuer'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Vous pourrez le modifier plus tard',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 12.5),
          ),
          _messageBox(),
        ],
      ),
    );
  }

  Widget _home() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(30, 30, 30, 24),
        children: [
          _coupleHeader(),
          const SizedBox(height: 34),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _featureIcon(Icons.photo_camera_outlined),
              const SizedBox(width: 20),
              _featureIcon(Icons.videocam_outlined),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Partagez vos photos\net vidéos',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'serif', fontSize: 27, fontWeight: FontWeight.w700, height: 1.05),
          ),
          const SizedBox(height: 18),
          const Text(
            'Capturez chaque instant et\nrevivez ensemble la magie\nde cette journée !',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15.5, height: 1.4),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _busy ? null : _manualUpload,
            style: _primaryStyle(),
            child: const Text('Déposer mes photos / vidéos'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
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
          _messageBox(),
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
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(30, 30, 30, 24),
        children: [
          _pageTitle('Partage automatique'),
          const SizedBox(height: 29),
          const Center(child: _ShareIllustration()),
          const SizedBox(height: 22),
          const Text(
            'Autorisez l’accès à vos photos\net vidéos',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700, fontSize: 20.5),
          ),
          const SizedBox(height: 22),
          _checkLine('Toutes les photos et vidéos prises pendant le mariage seront automatiquement envoyées'),
          _checkLine('Seuls les médias pris pendant l’événement seront partagés'),
          _checkLine('Vos photos restent privées ailleurs'),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _busy ? null : _enableAuto,
            style: _primaryStyle(),
            child: const Text('J’autorise'),
          ),
          const SizedBox(height: 5),
          TextButton(
            onPressed: () => setState(() => _tab = 0),
            child: const Text('Plus tard', style: TextStyle(color: _ink)),
          ),
          _messageBox(),
        ],
      ),
    );
  }

  Widget _activeStatus() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(30, 40, 30, 24),
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(color: _red, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 51),
                ),
                const Positioned(top: -5, right: -14, child: _ConfettiDots()),
              ],
            ),
          ),
          const SizedBox(height: 23),
          const Text(
            'Partage automatique\nactivé !',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700, fontSize: 25.5, height: 1.05),
          ),
          const SizedBox(height: 16),
          const Text(
            'Toutes les photos et vidéos que vous\nprenez pendant le mariage seront\nautomatiquement envoyées.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, height: 1.4),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(13)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.calendar_month_outlined, color: _deepRed, size: 23),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Période de partage\n03 juil. 2027 — 14:00\nau 04 juil. 2027 — 05:00',
                    style: TextStyle(fontSize: 13.8, height: 1.42, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          OutlinedButton(
            onPressed: _finishEvening,
            style: _outlineStyle(),
            child: const Text('Fin de soirée — arrêter le partage'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _busy ? null : _pauseAuto,
            child: const Text('Mettre en pause', style: TextStyle(color: _ink)),
          ),
        ],
      ),
    );
  }

  Widget _sendingStatus() {
    final total = _manualUploading ? _uploadTotal : (_sentCount + 1);
    final done = _manualUploading ? _uploadDone : _sentCount;
    final progress = _manualUploading && total > 0 ? (_uploadDone / total).clamp(0.0, 1.0) : null;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(30, 48, 30, 24),
        children: [
          const Text(
            'Envoi en cours...',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'serif', fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.cloud_upload, color: _red, size: 68),
          const SizedBox(height: 6),
          Text(
            '$done',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'serif', fontSize: 31, fontWeight: FontWeight.w700),
          ),
          const Text('médias envoyés', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 23),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(6),
            color: _red,
            backgroundColor: const Color(0xFFE8D7C7),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              4,
              (index) => Container(
                width: 61,
                height: 61,
                decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.image_outlined, color: _deepRed, size: 29),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Les médias sont envoyés en arrière-plan.\nVous pouvez continuer à utiliser votre téléphone.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _upToDateStatus() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(30, 57, 30, 24),
        children: [
          Center(
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _gold, width: 2.5)),
              child: const Icon(Icons.check, color: _olive, size: 50),
            ),
          ),
          const SizedBox(height: 27),
          const Text(
            'Tout est à jour !',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'serif', fontSize: 26.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 13),
          Text(
            '$_sentCount',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'serif', fontSize: 32, fontWeight: FontWeight.w700),
          ),
          const Text('médias envoyés', textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 27),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(13)),
            child: const Column(
              children: [
                Text(
                  'Merci de partager ces beaux\nsouvenirs avec nous !',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.5, height: 1.4),
                ),
                SizedBox(height: 11),
                Icon(Icons.favorite, color: _red, size: 22),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () => setState(() => _allUpToDate = false),
            child: const Text('Retour au statut', style: TextStyle(color: _deepRed)),
          ),
        ],
      ),
    );
  }

  Widget _endedStatus() {
    final end = _personalAutoEnd!;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(30, 44, 30, 24),
        children: [
          _pageTitle('Partage terminé'),
          const SizedBox(height: 30),
          const Icon(Icons.nightlight_round, color: _deepRed, size: 68),
          const SizedBox(height: 18),
          const Text(
            'Bonne fin de soirée !',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'serif', fontSize: 25.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 15),
          Text(
            'Le partage automatique a été arrêté le ${_dateTimeLabel(end)}.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14.5, height: 1.4),
          ),
          const SizedBox(height: 13),
          const Text(
            'Aucun média pris après cette heure ne sera envoyé automatiquement.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 25),
          FilledButton(onPressed: _manualUpload, style: _primaryStyle(), child: const Text('Envoyer manuellement')),
          const SizedBox(height: 5),
          TextButton(
            onPressed: () => _enableAuto(resetPersonalEnd: false),
            child: const Text(
              'J’ai cliqué par erreur — réactiver',
              style: TextStyle(color: _deepRed, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gallery() {
    final names = _recentNames;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
        children: [
          const Text(
            'Vos derniers envois',
            textAlign: TextAlign.left,
            style: TextStyle(fontFamily: 'serif', fontSize: 25, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: names.isEmpty ? 9 : (names.length > 9 ? 9 : names.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              final hasRealName = names.isNotEmpty && index < names.length;
              final name = hasRealName ? names[index] : '';
              final isVideo = hasRealName && <String>['mp4', 'mov', 'm4v'].contains(name.toLowerCase().split('.').last);
              final isLast = index == 8 && names.length > 9;
              return Container(
                decoration: BoxDecoration(
                  color: index.isEven ? const Color(0xFFEEDFD5) : const Color(0xFFF4EAE2),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: isLast
                      ? Text('+${names.length - 8}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))
                      : Icon(
                          isVideo ? Icons.play_circle_outline : Icons.image_outlined,
                          color: hasRealName ? _deepRed : Colors.black26,
                          size: 31,
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: _manualUpload, style: _outlineStyle(), child: const Text('Voir tous les médias')),
        ],
      ),
    );
  }

  Widget _more() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        children: [
          _pageTitle('Plus'),
          const SizedBox(height: 22),
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
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(11)),
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
      unselectedItemColor: const Color(0xFF4C4947),
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

class _RingsIllustration extends StatelessWidget {
  final double size;
  const _RingsIllustration({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.45,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: size * .10,
            top: size * .13,
            child: Transform.rotate(
              angle: -.26,
              child: Container(
                width: size * .72,
                height: size * .72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD1A846), width: 8),
                  boxShadow: const [BoxShadow(color: Color(0x44B8902E), blurRadius: 5)],
                ),
              ),
            ),
          ),
          Positioned(
            right: size * .09,
            top: size * .17,
            child: Transform.rotate(
              angle: .22,
              child: Container(
                width: size * .72,
                height: size * .72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE0BB62), width: 8),
                  boxShadow: const [BoxShadow(color: Color(0x44B8902E), blurRadius: 5)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareIllustration extends StatelessWidget {
  const _ShareIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 95,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 10,
            top: 14,
            child: Transform.rotate(
              angle: -.12,
              child: Container(
                width: 49,
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
            left: 55,
            top: 5,
            child: Container(
              width: 52,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF51493F), width: 2),
              ),
            ),
          ),
          Positioned(
            right: 5,
            bottom: 9,
            child: Container(
              width: 67,
              height: 48,
              decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 31),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiDots extends StatelessWidget {
  const _ConfettiDots();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 48,
      height: 42,
      child: Stack(
        children: [
          Positioned(left: 4, top: 3, child: Icon(Icons.circle, size: 6, color: _gold)),
          Positioned(right: 2, top: 10, child: Icon(Icons.circle, size: 5, color: _red)),
          Positioned(left: 15, bottom: 1, child: Icon(Icons.circle, size: 5, color: _gold)),
          Positioned(right: 12, bottom: 5, child: Icon(Icons.circle, size: 4, color: _deepRed)),
        ],
      ),
    );
  }
}

class _RoseFramePainter extends CustomPainter {
  const _RoseFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rose = Paint()..color = const Color(0xFFC20E23);
    final roseDark = Paint()..color = const Color(0xFF8E111C);
    final petal = Paint()..color = const Color(0xFFE33C4A);

    void drawRose(Offset center, double r) {
      for (var i = 0; i < 8; i++) {
        final angle = i * 0.785398;
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(0, -r * .34), width: r * .9, height: r * .58),
          i.isEven ? rose : petal,
        );
        canvas.restore();
      }
      canvas.drawCircle(center, r * .38, roseDark);
      canvas.drawCircle(center, r * .18, rose);
    }

    void drawPetal(Offset center, double w, double h, double angle) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: h), rose);
      canvas.restore();
    }

    drawRose(const Offset(16, 18), 34);
    drawRose(Offset(size.width - 16, 24), 28);
    drawRose(Offset(size.width - 10, size.height - 18), 31);
    drawRose(Offset(12, size.height - 34), 24);
    drawPetal(const Offset(78, 48), 30, 14, .62);
    drawPetal(const Offset(44, 86), 24, 12, -.52);
    drawPetal(Offset(size.width - 71, 82), 28, 13, -.66);
    drawPetal(Offset(size.width - 42, 125), 22, 11, .45);
    drawPetal(Offset(59, size.height - 120), 26, 12, .82);
    drawPetal(Offset(size.width - 69, size.height - 105), 30, 13, -.65);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
