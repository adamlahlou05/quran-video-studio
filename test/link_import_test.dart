import 'package:flutter_test/flutter_test.dart';
import 'package:quran_video_studio/core/services/link_import_service.dart';

void main() {
  group('detectLinkSource', () {
    test('TikTok (y compris liens courts)', () {
      expect(detectLinkSource('https://www.tiktok.com/@user/video/123'),
          LinkSource.tiktok);
      expect(
          detectLinkSource('https://vm.tiktok.com/ZMabc/'), LinkSource.tiktok);
    });

    test('YouTube et Shorts', () {
      expect(detectLinkSource('https://www.youtube.com/shorts/abc123'),
          LinkSource.youtube);
      expect(detectLinkSource('https://youtube.com/watch?v=xyz'),
          LinkSource.youtube);
      expect(detectLinkSource('https://youtu.be/xyz'), LinkSource.youtube);
    });

    test('Instagram Reels', () {
      expect(detectLinkSource('https://www.instagram.com/reel/abc/'),
          LinkSource.instagram);
    });

    test('lien direct vers un fichier vidéo (extension, casse ignorée)', () {
      expect(detectLinkSource('https://example.com/videos/clip.mp4'),
          LinkSource.direct);
      expect(detectLinkSource('https://cdn.site.org/a/b/Clip.WEBM'),
          LinkSource.direct);
    });

    test('inconnu : page web, URL invalide, schéma non http', () {
      expect(detectLinkSource('https://example.com/page'), LinkSource.unknown);
      expect(detectLinkSource('pas une url'), LinkSource.unknown);
      expect(detectLinkSource('ftp://serveur/video.mp4'), LinkSource.unknown);
    });

    test('un domaine contenant « tiktok » ailleurs ne matche pas', () {
      expect(detectLinkSource('https://nottiktok.com.evil.org/x.html'),
          LinkSource.unknown);
    });
  });
}
