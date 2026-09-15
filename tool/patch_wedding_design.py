from pathlib import Path
p=Path('lib/wedding_app.dart')
s=p.read_text()
if "import 'wedding_decor.dart';" not in s:
    s=s.replace("import 'upload_service.dart';", "import 'upload_service.dart';\nimport 'wedding_decor.dart';")
# Replace drawn rings everywhere with the validated site rings.
s=s.replace('_RingsIllustration(size: 118)', 'const SiteRings(width: 185)')
s=s.replace('_RingsIllustration(size: 110)', 'const SiteRings(width: 175)')
s=s.replace('_RingsIllustration(size: 100)', 'const SiteRings(width: 165)')
# Replace the fake painted floral frame with actual rose assets on splash.
s=s.replace("CustomPaint(\n            painter: const _RoseFramePainter(),\n            child:", "WeddingDecor(\n            child:")
# Add real roses around the main app pages too, behind content.
s=s.replace("body: IndexedStack(index: _tab, children: pages),", "body: WeddingDecor(child: IndexedStack(index: _tab, children: pages)),")
p.write_text(s)
