import 'dart:io';

import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';
import 'upload_service.dart';

class SyncReport {
  final int found;
  final int uploaded;
  final int skipped;
  final int failed;

  const SyncReport({
    required this.found,
    required this.uploaded,
    required this.skipped,
    required this.failed,
  });
}

class SyncService {
  static const _guestNameKey = 'guest_name';
  static const _autoEnabledKey = 'auto_enabled';
  static const _uploadedIdsKey = 'uploaded_asset_ids';
  static const _sentCountKey = 'sent_count';

  static Future<String> getGuestName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_guestNameKey) ?? '';
  }

  static Future<void> setGuestName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guestNameKey, value.trim());
  }

  static Future<bool> isAutoEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoEnabledKey) ?? false;
  }

  static Future<void> setAutoEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoEnabledKey, enabled);
  }

  static Future<int> sentCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_sentCountKey) ?? 0;
  }

  static Future<PermissionState> requestPhotoPermission() {
    return PhotoManager.requestPermissionExtend();
  }

  static bool _inEventWindow(DateTime date) {
    return !date.isBefore(AppConfig.eventStart) && !date.isAfter(AppConfig.eventEnd);
  }

  static Future<SyncReport> sync({bool background = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final guestName = (prefs.getString(_guestNameKey) ?? '').trim();
    final enabled = prefs.getBool(_autoEnabledKey) ?? false;

    if (guestName.length < 2 || !enabled) {
      return const SyncReport(found: 0, uploaded: 0, skipped: 0, failed: 0);
    }

    if (background) {
      await PhotoManager.setIgnorePermissionCheck(true);
    } else {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) {
        throw FileSystemException('Accès aux photos et vidéos refusé.');
      }
    }

    final filter = FilterOptionGroup(
      createTimeCond: DateTimeCond(
        min: AppConfig.eventStart,
        max: AppConfig.eventEnd,
      ),
      orders: const [OrderOption(type: OrderOptionType.createDate, asc: true)],
    );

    final uploadedIds = (prefs.getStringList(_uploadedIdsKey) ?? <String>[]).toSet();
    final uploader = UploadService();

    int page = 0;
    int found = 0;
    int uploaded = 0;
    int skipped = 0;
    int failed = 0;

    try {
      while (true) {
        final assets = await PhotoManager.getAssetListPaged(
          page: page,
          pageCount: 100,
          type: RequestType.common,
          filterOption: filter,
        );
        if (assets.isEmpty) break;

        for (final asset in assets) {
          if (asset.type != AssetType.image && asset.type != AssetType.video) continue;
          if (!_inEventWindow(asset.createDateTime)) continue;
          found++;

          if (uploadedIds.contains(asset.id)) {
            skipped++;
            continue;
          }

          final file = await asset.file;
          if (file == null || !await file.exists()) {
            failed++;
            continue;
          }

          try {
            final result = await uploader.uploadFile(
              file: file,
              guestName: guestName,
              originalName: asset.title,
              mimeType: asset.mimeType,
              uploadSource: 'automatic',
            );
            if (result.ok) {
              uploaded++;
              uploadedIds.add(asset.id);
              await prefs.setStringList(_uploadedIdsKey, uploadedIds.toList());
              await prefs.setInt(_sentCountKey, (prefs.getInt(_sentCountKey) ?? 0) + 1);
            } else {
              failed++;
            }
          } catch (_) {
            failed++;
          }
        }

        if (assets.length < 100) break;
        page++;
      }
    } finally {
      uploader.close();
    }

    return SyncReport(found: found, uploaded: uploaded, skipped: skipped, failed: failed);
  }
}
