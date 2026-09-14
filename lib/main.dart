import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'app_config.dart';
import 'sync_service.dart';
import 'upload_service.dart';

const _red = Color(0xFFB3131B);
const _deepRed = Color(0xFF841018);
const _gold = Color(0xFF9A8537);
const _cream = Color(0xFFFFFCF8);
const _soft = Color(0xFFF8F0E8);
const _ink = Color(0xFF241C18);

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
          hintStyle: const TextStyle(color: Colors.black38),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD9C5B2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD9C5B2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _red, width: 1.5),
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
  static const _onboardingKey = 'onboarding_done';
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

    if (mounted) {
      setState(() => _busy = false);
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      if (mounted) setState(() => _showSplash = false);
    }
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
            child: const Text('Annuler'),
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
              ),
            ),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
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

    if (mounted) {
      setState(() {
        _busy = true;
        _message = '';
        _allUpToDate = false;
      });
    }

    try {
      final permission = await SyncService.requestPhotoPermission();
      if (!permission.hasAccess) {
        if (mounted) {
          setState(() {
            _message =
                'L’accès aux photos et vidéos est nécessaire pour le partage automatique.';
          });
        }
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
        if (path == null) {
          failed++;
          _uploadDone++;
          if (mounted) setState(() {});
          continue;
        }

        final file = File(path);
        if (!await file.exists()) {
          failed++;
          _uploadDone++;
          if (mounted) setState(() {});
          continue;
        }

        try {
          final result = await uploader.uploadFile(
            file: file,
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

  String _clock(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _dateTimeLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à ${_clock(d)}';

  Widget _heartDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: _red.withValues(alpha: .25))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 9),
          child: Icon(Icons.favorite, color: _red, size: 14),
        ),
        Expanded(child: Divider(color: _red.withValues(alpha: .25))),
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
            fontSize: 27,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 7),
        _heartDivider(),
      ],
    );
  }

  ButtonStyle _redButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: _red,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  Widget _splash() {
    return Container(
      color: const Color(0xFFFFFAF5),
      padding: const EdgeInsets.fromLTRB(28, 54, 28, 44),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.favorite, color: _red, size: 58),
            const SizedBox(height: 14),
            const Icon(Icons.link, color: Color(0xFFC89A43), size: 82),
            const SizedBox(height: 24),
            const Text(
              'Emmanuel\n& Jennifer',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
                fontSize: 39,
                height: 1.08,
                color: _deepRed,
              ),
            ),
            const SizedBox(height: 16),
            _heartDivider(),
            const SizedBox(height: 12),
            const Text(
              'NOTRE MARIAGE',
              style: TextStyle(
                letterSpacing: 2.0,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              '03 Juillet 2027',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 22),
            const Text(
              'Partagez vos plus beaux\nsouvenirs avec nous',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.35),
            ),
            const Spacer(),
            const Text(
              'Merci d’être là !',
              style: TextStyle(
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
                color: _deepRed,
                fontSize: 25,
              ),
            ),
          ],
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 34),
      children: [
        const Text(
          'Emmanuel & Jennifer',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontStyle: FontStyle.italic,
            fontSize: 30,
            color: _deepRed,
          ),
        ),
        const SizedBox(height: 7),
        _heartDivider(),
        const SizedBox(height: 52),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _outlineFeatureIcon(Icons.photo_camera_outlined),
            const SizedBox(width: 28),
            _outlineFeatureIcon(Icons.play_arrow_rounded),
          ],
        ),
        const SizedBox(height: 36),
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
        const SizedBox(height: 20),
        const Text(
          'Capturez chaque instant et\nrevivez ensemble la magie\nde cette journée !',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, height: 1.35),
        ),
        const SizedBox(height: 52),
        FilledButton(
          onPressed: () => setState(() => _onboardingStep = 1),
          style: _redButtonStyle(),
          child: const Text('Commencer'),
        ),
        const SizedBox(height: 15),
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
    );
  }

  Widget _outlineFeatureIcon(IconData icon) {
    return Container(
      width: 80,
      height: 70,
      decoration: BoxDecoration(
        border: Border.all(color: _deepRed, width: 3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: _deepRed, size: 44),
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
          style: TextStyle(height: 1.4),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 43, 28, 34),
      children: [
        _title('Partage automatique'),
        const SizedBox(height: 32),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_outlined, size: 64, color: Color(0xFF4A4038)),
            SizedBox(width: 3),
            Icon(Icons.cloud_upload, size: 68, color: _red),
          ],
        ),
        const SizedBox(height: 30),
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
        const SizedBox(height: 24),
        _checkLine(
          'Toutes les photos et vidéos prises pendant le mariage seront automatiquement envoyées',
        ),
        _checkLine(
          'Seuls les médias pris pendant l’événement seront partagés',
        ),
        _checkLine('Vos photos restent privées ailleurs'),
        const SizedBox(height: 24),
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
                            'Autorisation refusée. Tu peux continuer plus tard depuis l’onglet Statut.';
                      });
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          style: _redButtonStyle(),
          child: const Text('J’autorise'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () async {
            await _finishOnboarding();
            if (mounted) setState(() => _tab = 0);
          },
          child: const Text('Plus tard', style: TextStyle(color: _ink)),
        ),
        if (_message.isNotEmpty) _messageBox(),
      ],
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
            child: Text(
              text,
              style: const TextStyle(fontSize: 15.5, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 72, 28, 34),
      children: [
        _title('Un dernier détail'),
        const SizedBox(height: 32),
        const Icon(Icons.person_outline, size: 68, color: _deepRed),
        const SizedBox(height: 26),
        const Text(
          'Entrez votre prénom\npour identifier vos médias',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
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
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _busy ? null : _saveNameAndEnable,
          style: _redButtonStyle(),
          child: const Text('Continuer'),
        ),
        const SizedBox(height: 14),
        const Text(
          'Vous pourrez le modifier plus tard',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        if (_message.isNotEmpty) _messageBox(),
      ],
    );
  }

  Widget _home() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 30),
      children: [
        const Text(
          'Emmanuel & Jennifer',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontStyle: FontStyle.italic,
            fontSize: 29,
            color: _deepRed,
          ),
        ),
        const SizedBox(height: 8),
        _heartDivider(),
        const SizedBox(height: 38),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _outlineFeatureIcon(Icons.photo_camera_outlined),
            const SizedBox(width: 28),
            _outlineFeatureIcon(Icons.play_arrow_rounded),
          ],
        ),
        const SizedBox(height: 32),
        const Text(
          'Partagez vos photos\net vidéos',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 27,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Capturez chaque instant et\nrevivez ensemble la magie\nde cette journée !',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16.5, height: 1.35),
        ),
        const SizedBox(height: 35),
        FilledButton(
          onPressed: _busy ? null : _manualUpload,
          style: _redButtonStyle(),
          child: const Text('Envoyer des photos / vidéos'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => setState(() {
            _tab = 1;
            _allUpToDate = false;
          }),
          style: OutlinedButton.styleFrom(
            foregroundColor: _deepRed,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: _red),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          child: Text(
            _enabled
                ? 'Voir le partage automatique'
                : _eveningEnded
                    ? 'Partage terminé'
                    : 'Activer le partage automatique',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        _messageBox(),
      ],
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 42, 28, 30),
      children: [
        _title('Partage automatique'),
        const SizedBox(height: 30),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_outlined, size: 60, color: Color(0xFF4A4038)),
            Icon(Icons.cloud_upload, size: 65, color: _red),
          ],
        ),
        const SizedBox(height: 25),
        const Text(
          'Autorisez l’accès à vos photos\net vidéos',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w700,
            fontSize: 21,
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
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _enableAuto,
          style: _redButtonStyle(),
          child: const Text('J’autorise'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _tab = 0),
          child: const Text('Plus tard', style: TextStyle(color: _ink)),
        ),
        _messageBox(),
      ],
    );
  }

  Widget _activeStatus() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 50, 28, 28),
      children: [
        Center(
          child: Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(
              color: _red,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 55),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Partage automatique\nactivé !',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 27,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Toutes les photos et vidéos que vous\nprenez pendant le mariage seront\nautomatiquement envoyées.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15.5, height: 1.4),
        ),
        const SizedBox(height: 25),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.calendar_today_outlined, color: _ink, size: 24),
              SizedBox(width: 13),
              Expanded(
                child: Text(
                  'Période de partage\n03 juil. 2027 — 14:00\nau 04 juil. 2027 — 05:00',
                  style: TextStyle(height: 1.4, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _busy ? null : _finishEvening,
          style: OutlinedButton.styleFrom(
            foregroundColor: _deepRed,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: _red),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          child: const Text(
            'Fin de soirée — arrêter le partage',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 9),
        TextButton(
          onPressed: _busy ? null : () => _syncNow(),
          child: const Text(
            'Synchroniser maintenant',
            style: TextStyle(color: _deepRed, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 2),
        TextButton(
          onPressed: _busy ? null : _pauseAuto,
          child: const Text(
            'Mettre en pause',
            style: TextStyle(color: Colors.black54),
          ),
        ),
        _messageBox(),
      ],
    );
  }

  Widget _sendingStatus() {
    final total = _manualUploading ? _uploadTotal : (_sentCount + 1);
    final done = _manualUploading ? _uploadDone : _sentCount;
    final progress = _manualUploading && total > 0
        ? (_uploadDone / total).clamp(0.0, 1.0)
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 65, 28, 30),
      children: [
        const Text(
          'Envoi en cours...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 27,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 26),
        const Icon(Icons.cloud_upload, color: _red, size: 78),
        const SizedBox(height: 10),
        Text(
          '$done',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
        ),
        const Text(
          'médias envoyés',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        LinearProgressIndicator(
          value: progress,
          minHeight: 9,
          borderRadius: BorderRadius.circular(6),
          color: _red,
          backgroundColor: const Color(0xFFE8D4C4),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            4,
            (index) => Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFE5D4C3)),
              ),
              child: const Icon(Icons.image_outlined, color: _deepRed),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Les médias sont envoyés en arrière-plan.\nVous pouvez continuer à utiliser votre téléphone.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: Colors.black54,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _upToDateStatus() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 72, 28, 30),
      children: [
        Center(
          child: Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _gold, width: 3),
            ),
            child: const Icon(
              Icons.check,
              color: Color(0xFF71802F),
              size: 52,
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Tout est à jour !',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '$_sentCount',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
        ),
        const Text(
          'médias envoyés',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            children: [
              Text(
                'Merci de partager ces beaux\nsouvenirs avec nous !',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15.5, height: 1.35),
              ),
              SizedBox(height: 14),
              Icon(Icons.favorite, color: _red, size: 24),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => setState(() => _allUpToDate = false),
          style: OutlinedButton.styleFrom(
            foregroundColor: _deepRed,
            minimumSize: const Size.fromHeight(50),
            side: const BorderSide(color: _red),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
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
        _messageBox(),
      ],
    );
  }

  Widget _endedStatus() {
    final end = _personalAutoEnd!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 55, 28, 30),
      children: [
        _title('Partage terminé'),
        const SizedBox(height: 34),
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
        const SizedBox(height: 18),
        Text(
          'Le partage automatique a été arrêté le ${_dateTimeLabel(end)}.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15.5, height: 1.4),
        ),
        const SizedBox(height: 18),
        const Text(
          'Aucun média pris après cette heure ne sera envoyé automatiquement.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 30),
        FilledButton(
          onPressed: _manualUpload,
          style: _redButtonStyle(),
          child: const Text('Envoyer manuellement'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => _enableAuto(resetPersonalEnd: false),
          child: const Text(
            'J’ai cliqué par erreur — réactiver',
            style: TextStyle(color: _deepRed, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _gallery() {
    final names = _recentNames;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 28),
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
        if (names.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  color: _deepRed,
                  size: 58,
                ),
                const SizedBox(height: 14),
                Text(
                  '$_sentCount média(s) envoyé(s)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Les prochains envois manuels apparaîtront ici.',
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
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: _manualUpload,
          style: OutlinedButton.styleFrom(
            foregroundColor: _deepRed,
            minimumSize: const Size.fromHeight(50),
            side: const BorderSide(color: _red),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: const Text(
            'Ajouter des photos / vidéos',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _more() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
      children: [
        _title('Plus'),
        const SizedBox(height: 24),
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
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: _finishEvening,
              style: OutlinedButton.styleFrom(
                foregroundColor: _deepRed,
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: _red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: const Text(
                'Fin de soirée — arrêter le partage',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }

  Widget _settingCard(IconData icon, String title, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
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
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.35,
                  ),
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
      backgroundColor: Colors.white,
      selectedItemColor: _red,
      unselectedItemColor: const Color(0xFF3C3835),
      selectedFontSize: 11,
      unselectedFontSize: 11,
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
        body: SafeArea(child: _onboarding()),
      );
    }

    final pages = [_home(), _status(), _gallery(), _more()];
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: IndexedStack(index: _tab, children: pages),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }
}
