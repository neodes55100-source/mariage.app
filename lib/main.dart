import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'app_config.dart';
import 'sync_service.dart';
import 'upload_service.dart';

const _red = Color(0xFFA90E24);
const _deepRed = Color(0xFF7E1421);
const _gold = Color(0xFFC49A45);
const _cream = Color(0xFFFFFBF7);
const _soft = Color(0xFFF7EFE8);

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
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFFFE8E8),
          labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
        ),
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

class _WeddingShellState extends State<WeddingShell> with WidgetsBindingObserver {
  final _nameController = TextEditingController();
  int _tab = 0;
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
        title: const Text('Un dernier détail'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Votre nom / prénom',
            hintText: 'Ex. Jean Dupont',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
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

  Future<void> _enableAuto() async {
    final name = await _guestName();
    if (name == null) return;

    setState(() {
      _busy = true;
      _message = '';
    });

    try {
      final permission = await SyncService.requestPhotoPermission();
      if (!permission.hasAccess) {
        _message = 'L’accès aux photos et vidéos est nécessaire pour le partage automatique.';
        return;
      }
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
      _message = 'Partage automatique activé.';
      await _syncNow(silent: true);
    } catch (e) {
      _message = 'Impossible d’activer le partage : $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disableAuto() async {
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
    if (!silent && mounted) setState(() => _busy = true);
    try {
      final report = await SyncService.sync();
      _sentCount = await SyncService.sentCount();
      if (!silent) {
        _message = report.uploaded > 0
            ? '${report.uploaded} nouveau(x) média(s) envoyé(s).'
            : 'Tout est à jour !';
      }
    } catch (e) {
      if (!silent) _message = 'Synchronisation impossible : $e';
    } finally {
      if (mounted) setState(() => _busy = false);
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
      _busy = true;
      _message = 'Envoi en cours…';
    });

    int uploaded = 0;
    int failed = 0;
    final uploader = UploadService();
    try {
      for (final item in picked.files) {
        final path = item.path;
        if (path == null) {
          failed++;
          continue;
        }
        final file = File(path);
        if (!await file.exists()) {
          failed++;
          continue;
        }
        try {
          final result = await uploader.uploadFile(
            file: file,
            guestName: name,
            originalName: item.name,
            mimeType: _mimeFor(item.name),
          );
          if (result.ok) {
            uploaded++;
          } else {
            failed++;
          }
        } catch (_) {
          failed++;
        }
      }
    } finally {
      uploader.close();
    }

    if (uploaded > 0) {
      final prefs = await SharedPreferences.getInstance();
      _sentCount = (prefs.getInt('sent_count') ?? 0) + uploaded;
      await prefs.setInt('sent_count', _sentCount);
    }

    if (mounted) {
      setState(() {
        _busy = false;
        _tab = 2;
        _message = failed == 0
            ? '$uploaded média(s) envoyé(s) avec succès.'
            : '$uploaded envoyé(s), $failed échec(s).';
      });
    }
  }

  Widget _pageTitle(String title, {String? subtitle}) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w700,
            color: Color(0xFF281E1B),
            fontFamily: 'serif',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Divider(color: _red.withValues(alpha: .35))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.favorite, color: _red, size: 15),
            ),
            Expanded(child: Divider(color: _red.withValues(alpha: .35))),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.35)),
        ],
      ],
    );
  }

  Widget _nameField() {
    return TextField(
      controller: _nameController,
      enabled: !_busy,
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Votre nom / prénom',
        hintText: 'Ex. Jean Dupont',
        prefixIcon: Icon(Icons.person_outline, color: _deepRed),
      ),
    );
  }

  Widget _messageBox() {
    if (_message.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(16)),
      child: Text(_message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _home() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 22, offset: const Offset(0, 8))],
          ),
          child: Column(
            children: [
              Image.network(
                '${AppConfig.siteBaseUrl}/assets/img/rings-design2.png',
                height: 150,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.favorite, color: _red, size: 72),
              ),
              const Text(
                'Emmanuel & Jennifer',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic, color: _deepRed, fontFamily: 'serif'),
              ),
              const SizedBox(height: 8),
              const Text('NOTRE MARIAGE', style: TextStyle(letterSpacing: 2.2, fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 5),
              const Text('03 juillet 2027', style: TextStyle(fontWeight: FontWeight.w700, color: _gold, fontSize: 16)),
              const SizedBox(height: 18),
              const Text(
                'Capturez chaque instant et partagez vos plus beaux souvenirs avec nous.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _nameField(),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy ? null : _manualUpload,
          style: FilledButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(58),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Envoyer des photos / vidéos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => setState(() => _tab = 1),
          style: OutlinedButton.styleFrom(
            foregroundColor: _deepRed,
            minimumSize: const Size.fromHeight(56),
            side: const BorderSide(color: _red),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          icon: const Icon(Icons.autorenew_rounded),
          label: Text(_enabled ? 'Voir le partage automatique' : 'Activer le partage automatique', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 14),
        const Text(
          'L’envoi manuel reste disponible avant, pendant et après le mariage. La période 14 h → 5 h concerne uniquement le partage automatique.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, height: 1.4),
        ),
        _messageBox(),
      ],
    );
  }

  Widget _status() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
      children: [
        _pageTitle('Partage automatique', subtitle: 'Autorisez l’accès pour partager automatiquement les médias pris pendant le mariage.'),
        const SizedBox(height: 26),
        if (!_enabled) ...[
          _infoLine('Toutes les photos et vidéos prises pendant la période seront détectées.'),
          _infoLine('Seuls les médias du 03/07/2027 à 14 h au 04/07/2027 à 5 h seront envoyés.'),
          _infoLine('Vos autres photos et vidéos restent privées.'),
          const SizedBox(height: 18),
          _nameField(),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _enableAuto,
            style: FilledButton.styleFrom(backgroundColor: _red, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
            child: const Text('J’autorise', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          TextButton(onPressed: () => setState(() => _tab = 0), child: const Text('Plus tard')),
        ] else ...[
          const SizedBox(height: 10),
          const Icon(Icons.check_circle, color: _red, size: 84),
          const SizedBox(height: 14),
          const Text('Partage automatique activé !', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, fontFamily: 'serif')),
          const SizedBox(height: 12),
          Text('$_sentCount média(s) envoyé(s)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(20)),
            child: const Row(
              children: [
                Icon(Icons.calendar_month_outlined, color: _deepRed),
                SizedBox(width: 12),
                Expanded(child: Text('Période de partage\n03 juillet 2027 — 14:00\n04 juillet 2027 — 05:00', style: TextStyle(height: 1.45, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _syncNow(),
            icon: const Icon(Icons.sync),
            label: const Text('Synchroniser maintenant'),
            style: OutlinedButton.styleFrom(foregroundColor: _deepRed, minimumSize: const Size.fromHeight(52), side: const BorderSide(color: _red)),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _busy ? null : _disableAuto, child: const Text('Arrêter le partage', style: TextStyle(color: _red, fontWeight: FontWeight.w700))),
        ],
        if (_busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(color: _red),
        ],
        _messageBox(),
      ],
    );
  }

  Widget _infoLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: _red, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15.5, height: 1.35))),
        ],
      ),
    );
  }

  Widget _gallery() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
      children: [
        _pageTitle('Vos derniers envois', subtitle: 'Retrouvez ici le suivi de vos médias envoyés au mariage.'),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: _gold.withValues(alpha: .35))),
          child: Column(
            children: [
              const Icon(Icons.photo_library_outlined, color: _deepRed, size: 54),
              const SizedBox(height: 10),
              Text('$_sentCount', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: _deepRed)),
              const Text('média(s) envoyé(s)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 18),
              const Text('Les photos et vidéos sont envoyées vers l’album du mariage et leur publication est ensuite gérée par le site.', textAlign: TextAlign.center, style: TextStyle(height: 1.4, color: Colors.black54)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy ? null : _manualUpload,
          style: FilledButton.styleFrom(backgroundColor: _red, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Ajouter des photos / vidéos', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => setState(() => _tab = 0),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Retour à l’accueil'),
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(color: _red),
        ],
        _messageBox(),
      ],
    );
  }

  Widget _more() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
      children: [
        _pageTitle('Plus'),
        const SizedBox(height: 24),
        _settingsCard(Icons.person_outline, 'Identité', _nameController.text.trim().isEmpty ? 'Aucun nom renseigné' : _nameController.text.trim()),
        _settingsCard(Icons.lock_outline, 'Confidentialité', 'Seuls les médias choisis manuellement ou pris pendant la période automatique sont envoyés.'),
        _settingsCard(Icons.schedule_outlined, 'Période automatique', '03/07/2027 14:00 → 04/07/2027 05:00'),
        if (Platform.isIOS)
          _settingsCard(Icons.phone_iphone, 'iPhone', 'iOS décide du moment des tâches en arrière-plan. Les médias manquants sont rattrapés à la réouverture.'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() => _tab = 0),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Retour à l’accueil'),
          style: OutlinedButton.styleFrom(foregroundColor: _deepRed, minimumSize: const Size.fromHeight(52), side: const BorderSide(color: _red)),
        ),
      ],
    );
  }

  Widget _settingsCard(IconData icon, String title, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _gold.withValues(alpha: .25))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _deepRed),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(text, style: const TextStyle(color: Colors.black54, height: 1.35))])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_home(), _status(), _gallery(), _more()];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: _red), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.verified_outlined), selectedIcon: Icon(Icons.verified, color: _red), label: 'Statut'),
          NavigationDestination(icon: Icon(Icons.photo_library_outlined), selectedIcon: Icon(Icons.photo_library, color: _red), label: 'Galerie'),
          NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz, color: _red), label: 'Plus'),
        ],
      ),
    );
  }
}
