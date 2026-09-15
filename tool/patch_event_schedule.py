from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    if old not in text:
        raise SystemExit(f'Bloc introuvable pour {label}: {path}')
    path.write_text(text.replace(old, new, 1))


# 1) Ne scanner aucun média avant le début du mariage, ni après la fin.
sync = Path('lib/sync_service.dart')
replace_once(
    sync,
    """    final effectiveEnd = _effectiveEnd(personalEnd);\n\n    if (effectiveEnd.isBefore(AppConfig.eventStart)) {\n      return const SyncReport(found: 0, uploaded: 0, skipped: 0, failed: 0);\n    }\n\n    if (background) {\n""",
    """    final effectiveEnd = _effectiveEnd(personalEnd);\n    final now = DateTime.now();\n\n    // Le partage peut être armé des mois à l'avance, mais aucun média n'est\n    // analysé ni envoyé avant le début du mariage. Il s'arrête aussi après\n    // la fin effective de la période.\n    if (effectiveEnd.isBefore(AppConfig.eventStart) ||\n        now.isBefore(AppConfig.eventStart) ||\n        now.isAfter(effectiveEnd)) {\n      return const SyncReport(found: 0, uploaded: 0, skipped: 0, failed: 0);\n    }\n\n    if (background) {\n""",
    'garde de fenêtre événement',
)


# 2) Programmer Android pour ne commencer les vérifications qu'au mariage.
site = Path('lib/wedding_app_site.dart')
replace_once(
    site,
    """  bool get _eveningEnded => _personalAutoEnd != null;\n""",
    """  bool get _eveningEnded => _personalAutoEnd != null;\n\n  bool get _waitingForEvent =>\n      _enabled && DateTime.now().isBefore(AppConfig.eventStart);\n""",
    'état programmé',
)

replace_once(
    site,
    """  Future<void> _registerAutoTask() async {\n    if (!Platform.isAndroid) return;\n    await Workmanager().registerPeriodicTask(\n      AppConfig.backgroundUniqueName,\n      AppConfig.backgroundTaskName,\n      frequency: const Duration(minutes: 15),\n      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,\n      constraints: Constraints(networkType: NetworkType.connected),\n    );\n  }\n""",
    """  Future<void> _registerAutoTask() async {\n    if (!Platform.isAndroid) return;\n\n    final now = DateTime.now();\n    if (now.isAfter(AppConfig.eventEnd)) {\n      await _cancelAutoTask();\n      return;\n    }\n\n    final initialDelay = now.isBefore(AppConfig.eventStart)\n        ? AppConfig.eventStart.difference(now)\n        : Duration.zero;\n\n    await Workmanager().registerPeriodicTask(\n      AppConfig.backgroundUniqueName,\n      AppConfig.backgroundTaskName,\n      frequency: const Duration(minutes: 15),\n      initialDelay: initialDelay,\n      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,\n      constraints: Constraints(networkType: NetworkType.connected),\n    );\n  }\n""",
    'programmation Android différée',
)

replace_once(
    site,
    """  Widget _status() {\n    if (_manualUploading || _syncing) return _sendingStatus();\n    if (_eveningEnded && !_enabled) return _endedStatus();\n    if (!_enabled) return _inactiveStatus();\n    if (_allUpToDate) return _upToDateStatus();\n    return _activeStatus();\n  }\n""",
    """  Widget _status() {\n    if (_manualUploading || _syncing) return _sendingStatus();\n    if (_eveningEnded && !_enabled) return _endedStatus();\n    if (!_enabled) return _inactiveStatus();\n    if (_waitingForEvent) return _scheduledStatus();\n    if (_allUpToDate) return _upToDateStatus();\n    return _activeStatus();\n  }\n""",
    'statut avant événement',
)

scheduled_widget = """
  Widget _scheduledStatus() {
    return _statusBase(
      children: [
        const Icon(Icons.schedule_rounded, color: _red, size: 72),
        const SizedBox(height: 18),
        const Text(
          'Partage automatique programmé',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Il est bien activé sur ce téléphone. Aucun média ne sera analysé ni envoyé avant le début du mariage.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 22),
        _infoCard(
          Icons.calendar_month_outlined,
          'Démarrage automatique',
          '03 juillet 2027 · 14:00',
        ),
        const SizedBox(height: 12),
        _infoCard(
          Icons.schedule_outlined,
          'Fin automatique',
          '04 juillet 2027 · 05:00',
        ),
        const SizedBox(height: 16),
        const Text(
          'À partir de 14:00, Android effectuera les envois en arrière-plan dès que les conditions du téléphone le permettent et qu’une connexion est disponible.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.4, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _pauseAuto,
          child: const Text('Mettre en pause', style: TextStyle(color: _ink)),
        ),
      ],
    );
  }

"""

replace_once(
    site,
    """  Widget _activeStatus() {\n""",
    scheduled_widget + """  Widget _activeStatus() {\n""",
    'écran statut programmé',
)

print('Event scheduling patch applied.')
