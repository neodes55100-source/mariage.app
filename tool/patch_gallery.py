from pathlib import Path

path = Path('lib/wedding_app_site.dart')
text = path.read_text(encoding='utf-8')


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Patch galerie impossible ({label}) : occurrence attendue 1, trouvée {count}')
    text = text.replace(old, new, 1)


replace_once(
    "import 'app_config.dart';\nimport 'sync_service.dart';",
    "import 'app_config.dart';\nimport 'gallery_service.dart';\nimport 'sync_service.dart';",
    'import gallery_service',
)

replace_once(
    "  static const _onboardingKey = 'onboarding_done_site_design_v1';\n  static const _recentNamesKey = 'recent_upload_names';",
    "  static const _onboardingKey = 'onboarding_done_site_design_v1';\n  static const _galleryCacheKey = 'gallery_media_cache_v1';\n  static const _galleryPageSize = 12;",
    'constantes galerie',
)

replace_once(
    "  String _message = '';\n  List<String> _recentNames = <String>[];",
    "  String _message = '';\n  List<GalleryMedia> _galleryMedia = <GalleryMedia>[];\n  bool _galleryLoading = false;\n  String _galleryError = '';\n  int _photoPage = 0;\n  int _videoPage = 0;",
    'etat galerie',
)

replace_once(
    "  @override\n  void didChangeAppLifecycleState(AppLifecycleState state) {\n    if (state == AppLifecycleState.resumed && _enabled) {\n      _syncNow(silent: true);\n    }\n  }",
    "  @override\n  void didChangeAppLifecycleState(AppLifecycleState state) {\n    if (state == AppLifecycleState.resumed) {\n      if (_enabled) _syncNow(silent: true);\n      if (_tab == 2) _refreshGallery(silent: true);\n    }\n  }",
    'reprise application',
)

replace_once(
    "    _onboardingDone = prefs.getBool(_onboardingKey) ?? false;\n    _recentNames = prefs.getStringList(_recentNamesKey) ?? <String>[];\n    if (!mounted) return;\n    setState(() => _busy = false);\n    await Future<void>.delayed(const Duration(milliseconds: 1600));\n    if (mounted) setState(() => _showSplash = false);",
    "    _onboardingDone = prefs.getBool(_onboardingKey) ?? false;\n    final cachedGallery = prefs.getString(_galleryCacheKey);\n    if (cachedGallery != null && cachedGallery.isNotEmpty) {\n      _galleryMedia = GalleryService.decodeCache(cachedGallery);\n    }\n    if (!mounted) return;\n    setState(() => _busy = false);\n    await Future<void>.delayed(const Duration(milliseconds: 1600));\n    if (mounted) setState(() => _showSplash = false);\n    if (_nameController.text.trim().length >= 2) {\n      _refreshGallery(silent: true);\n    }",
    'chargement cache galerie',
)

manual_old = r'''  Future<void> _manualUpload() async {
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
'''

manual_new = r'''  Future<void> _refreshGallery({bool silent = false}) async {
    final name = _nameController.text.trim();
    if (name.length < 2 || _galleryLoading || !mounted) return;

    setState(() {
      _galleryLoading = true;
      if (!silent) _galleryError = '';
    });

    try {
      final media = await GalleryService.fetchForGuest(name);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_galleryCacheKey, GalleryService.encodeCache(media));
      if (!mounted) return;
      setState(() {
        _galleryMedia = media;
        _galleryError = '';
        _photoPage = _validGalleryPage(
          _photoPage,
          media.where((item) => item.isPhoto).length,
        );
        _videoPage = _validGalleryPage(
          _videoPage,
          media.where((item) => item.isVideo).length,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _galleryError =
            'Impossible de mettre la galerie à jour. Les derniers médias connus restent affichés.';
      });
    } finally {
      if (mounted) setState(() => _galleryLoading = false);
    }
  }

  int _validGalleryPage(int page, int itemCount) {
    if (itemCount <= 0) return 0;
    final lastPage = (itemCount - 1) ~/ _galleryPageSize;
    if (page < 0) return 0;
    if (page > lastPage) return lastPage;
    return page;
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
    }

    if (!mounted) return;
    setState(() {
      _manualUploading = false;
      _allUpToDate = failed == 0;
      _message = failed == 0
          ? '$uploaded média(s) envoyé(s) avec succès.'
          : '$uploaded envoyé(s), $failed échec(s).';
      if (uploaded > 0) _tab = 2;
    });

    if (uploaded > 0) {
      await _refreshGallery();
    }
  }
'''
replace_once(manual_old, manual_new, 'upload manuel et synchronisation')

gallery_old = r'''  Widget _gallery() {
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
'''

gallery_new = r'''  Future<void> _openGalleryMedia(GalleryMedia item) async {
    if (item.isVideo) {
      await launchUrl(Uri.parse(item.mediaUrl), mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Center(
                    child: Image.network(
                      item.mediaUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 58,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _deepRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _galleryTile(GalleryMedia item) {
    return Material(
      color: _soft,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openGalleryMedia(item),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.isPhoto)
              Image.network(
                item.thumbUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.photo_outlined, color: _deepRed, size: 34),
                ),
              )
            else
              Container(
                color: const Color(0xFF3B3030),
                child: const Center(
                  child: Icon(Icons.videocam_outlined, color: Colors.white, size: 38),
                ),
              ),
            if (item.isVideo)
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 42,
                  shadows: [Shadow(blurRadius: 5, color: Colors.black54)],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _galleryPagination({
    required int page,
    required int pageCount,
    required ValueChanged<int> onChanged,
  }) {
    if (pageCount <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.outlined(
            onPressed: page > 0 ? () => onChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Text(
              'Page ${page + 1} / $pageCount',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton.outlined(
            onPressed: page + 1 < pageCount ? () => onChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _gallerySection({
    required String title,
    required IconData icon,
    required List<GalleryMedia> items,
    required int page,
    required ValueChanged<int> onPageChanged,
  }) {
    final pageCount = items.isEmpty ? 1 : (items.length + _galleryPageSize - 1) ~/ _galleryPageSize;
    final safePage = _validGalleryPage(page, items.length);
    final start = safePage * _galleryPageSize;
    final end = (start + _galleryPageSize) > items.length
        ? items.length
        : start + _galleryPageSize;
    final visible = items.isEmpty ? <GalleryMedia>[] : items.sublist(start, end);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6D8D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _deepRed, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  title == 'Photos' ? 'Aucune photo pour le moment.' : 'Aucune vidéo pour le moment.',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visible.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) => _galleryTile(visible[index]),
            ),
          _galleryPagination(
            page: safePage,
            pageCount: pageCount,
            onChanged: onPageChanged,
          ),
        ],
      ),
    );
  }

  Widget _gallery() {
    final photos = _galleryMedia.where((item) => item.isPhoto).toList();
    final videos = _galleryMedia.where((item) => item.isVideo).toList();

    return SafeArea(
      child: RefreshIndicator(
        color: _red,
        onRefresh: () => _refreshGallery(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
          children: [
            _siteHeader(compact: true),
            const SizedBox(height: 16),
            _pageTitle('Vos derniers envois'),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _manualUploading ? null : _manualUpload,
              style: _primaryStyle(),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Ajouter des photos / vidéos'),
            ),
            const SizedBox(height: 7),
            TextButton.icon(
              onPressed: _galleryLoading ? null : () => _refreshGallery(),
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser depuis le site'),
              style: TextButton.styleFrom(foregroundColor: _deepRed),
            ),
            if (_galleryLoading) ...[
              const SizedBox(height: 5),
              const LinearProgressIndicator(
                minHeight: 3,
                color: _red,
                backgroundColor: Color(0xFFEBDDDD),
              ),
            ],
            if (_galleryError.isNotEmpty) ...[
              const SizedBox(height: 10),
              _infoCard(
                Icons.sync_problem_outlined,
                'Mise à jour impossible',
                _galleryError,
              ),
            ],
            _messageBox(),
            const SizedBox(height: 16),
            if (_galleryMedia.isEmpty && !_galleryLoading)
              _infoCard(
                Icons.photo_library_outlined,
                'Aucun média',
                'Les photos et vidéos conservées sur le site pour ce prénom apparaîtront ici.',
              )
            else ...[
              _gallerySection(
                title: 'Photos',
                icon: Icons.photo_outlined,
                items: photos,
                page: _photoPage,
                onPageChanged: (value) => setState(() => _photoPage = value),
              ),
              const SizedBox(height: 15),
              _gallerySection(
                title: 'Vidéos',
                icon: Icons.videocam_outlined,
                items: videos,
                page: _videoPage,
                onPageChanged: (value) => setState(() => _videoPage = value),
              ),
            ],
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () async {
                final uri = Uri.parse('${AppConfig.siteBaseUrl}/album.php');
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              style: _outlineStyle(),
              child: const Text('Voir l’album complet sur le site'),
            ),
          ],
        ),
      ),
    );
  }
'''
replace_once(gallery_old, gallery_new, 'galerie paginee')

replace_once(
    "      onTap: (value) => setState(() {\n        _tab = value;\n        if (value != 1) _allUpToDate = false;\n      }),",
    "      onTap: (value) {\n        setState(() {\n          _tab = value;\n          if (value != 1) _allUpToDate = false;\n        });\n        if (value == 2) _refreshGallery(silent: true);\n      },",
    'navigation galerie',
)

path.write_text(text, encoding='utf-8')
print('Patch galerie appliqué.')
