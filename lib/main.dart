import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:workmanager/workmanager.dart';

import 'app_config.dart';
import 'sync_service.dart';

const _red = Color(0xFF9F1024);
const _deepRed = Color(0xFF74101E);
const _gold = Color(0xFFC79A3B);
const _cream = Color(0xFFFFFBF8);

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
        colorScheme: ColorScheme.fromSeed(seedColor: _red, brightness: Brightness.light),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: _gold.withValues(alpha: .45)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _red, width: 1.6),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _nameController = TextEditingController();
  bool _enabled = false;
  bool _busy = true;
  int _sentCount = 0;
  String _message = '';

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
    _nameController.text = await SyncService.getGuestName();
    _enabled = await SyncService.isAutoEnabled();
    _sentCount = await SyncService.sentCount();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _enable() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _message = 'Entre ton nom et ton prénom.');
      return;
    }

    setState(() {
      _busy = true;
      _message = '';
    });

    try {
      final permission = await SyncService.requestPhotoPermission();
      if (!permission.hasAccess) {
        setState(() => _message = 'L’accès aux photos et vidéos est nécessaire.');
        return;
      }

      await SyncService.setGuestName(name);
      await SyncService.setAutoEnabled(true);
      if (Platform.isAndroid) {
        await Workmanager().registerPeriodicTask(
          AppConfig.backgroundUniqueName,
          AppConfig.backgroundTaskName,
          frequency: const Duration(minutes: 15),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
          constraints: Constraints(networkType: NetworkType.connected),
        );
      }

      _enabled = true;
      setState(() => _message = 'Partage automatique activé.');
      await _syncNow(silent: true);
    } catch (e) {
      setState(() => _message = 'Impossible d’activer le partage : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable() async {
    await SyncService.setAutoEnabled(false);
    if (Platform.isAndroid) {
      await Workmanager().cancelByUniqueName(AppConfig.backgroundUniqueName);
    }
    if (mounted) {
      setState(() {
        _enabled = false;
        _message = 'Partage automatique arrêté.';
      });
    }
  }

  Future<void> _syncNow({bool silent = false}) async {
    if (!_enabled) return;
    if (!silent) setState(() => _busy = true);
    try {
      final report = await SyncService.sync();
      _sentCount = await SyncService.sentCount();
      if (mounted && !silent) {
        setState(() {
          _message = report.uploaded > 0
              ? '${report.uploaded} nouveau(x) média(s) envoyé(s).'
              : 'Tout est à jour.';
        });
      }
    } catch (e) {
      if (mounted && !silent) setState(() => _message = 'Synchronisation impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  children: [
                    Image.network(
                      '${AppConfig.siteBaseUrl}/assets/img/rings-design2.png',
                      height: 130,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.favorite, color: _red, size: 72),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Emmanuel & Jennifer',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 31, fontWeight: FontWeight.w700, color: _deepRed),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '03 juillet 2027',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _gold),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Partagez automatiquement les photos et vidéos prises pendant notre mariage.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _gold.withValues(alpha: .30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Votre nom / prénom', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      enabled: !_enabled && !_busy,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(hintText: 'Ex. Jean Dupont'),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: const Color(0xFFFFF4F4), borderRadius: BorderRadius.circular(18)),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.schedule_rounded, color: _red),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Seuls les médias pris du 03/07/2027 à 14 h au 04/07/2027 à 5 h seront envoyés.',
                              style: TextStyle(height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!_enabled)
                      FilledButton.icon(
                        onPressed: _busy ? null : _enable,
                        style: FilledButton.styleFrom(
                          backgroundColor: _red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Autoriser et activer le partage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6FBF5),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF7E9A72).withValues(alpha: .35)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF69845F), size: 48),
                            const SizedBox(height: 8),
                            const Text('Partage automatique activé', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            Text('$_sentCount média(s) envoyé(s)', style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _syncNow(),
                        icon: const Icon(Icons.sync),
                        label: const Text('Synchroniser maintenant'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy ? null : _disable,
                        child: const Text('Arrêter le partage', style: TextStyle(color: _red)),
                      ),
                    ],
                    if (_busy) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(color: _red),
                    ],
                    if (_message.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(_message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Les autres photos de votre téléphone restent privées. Vous pouvez arrêter le partage à tout moment.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, height: 1.35),
              ),
              if (Platform.isIOS) ...[
                const SizedBox(height: 10),
                const Text(
                  'Sur iPhone, iOS décide quand les tâches en arrière-plan peuvent s’exécuter. L’application rattrape les médias manquants dès qu’elle est rouverte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black45, fontSize: 12, height: 1.35),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
