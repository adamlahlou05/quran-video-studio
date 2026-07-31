import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../core/models/models.dart';
import '../../core/services/link_import_service.dart';
import '../../core/services/media_probe.dart';
import '../../providers/editor_controller.dart';

/// Import d'une vidéo d'arrière-plan depuis un lien.
///
/// Réservé aux contenus que l'utilisateur a le droit d'utiliser (vidéos
/// personnelles, banques libres de droits, autorisations obtenues). Les liens
/// TikTok / YouTube / Instagram sont reconnus et expliqués, mais aucun
/// téléchargement n'est tenté pour ces plateformes : elles n'offrent pas
/// d'API officielle de téléchargement de vidéos tierces, et l'application ne
/// contourne aucune protection. Seuls les liens directs vers un fichier
/// vidéo sont téléchargés.
class ImportLinkSheet extends ConsumerStatefulWidget {
  const ImportLinkSheet({super.key});

  @override
  ConsumerState<ImportLinkSheet> createState() => _ImportLinkSheetState();
}

class _ImportLinkSheetState extends ConsumerState<ImportLinkSheet> {
  final TextEditingController _urlController = TextEditingController();
  bool _downloading = false;
  double? _progress;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      setState(() {
        _urlController.text = text;
        _error = null;
      });
    }
  }

  Future<void> _download() async {
    final url = _urlController.text.trim();
    setState(() {
      _downloading = true;
      _progress = null;
      _error = null;
    });
    File? file;
    try {
      file = await LinkImportService().download(
        url,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      final duration = await MediaProbe.durationMs(file.path);
      if (duration == null) {
        await file.delete();
        throw Exception('le fichier téléchargé n’est pas une vidéo lisible');
      }
      // Copie dans la galerie (best-effort) + ajout direct à la séquence.
      try {
        await Gal.putVideo(file.path, album: 'Quran Video Studio');
      } catch (_) {
        // La galerie peut refuser (permission) : le clip reste utilisable.
      }
      ref
          .read(editorProvider.notifier)
          .addClip(BackgroundClip(path: file.path, durationMs: duration));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vidéo importée et ajoutée à la séquence ✓'),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = 'Téléchargement impossible — $e'.replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _urlController.text.trim();
    final source = url.isEmpty ? null : detectLinkSource(url);
    final downloadable = source == LinkSource.direct ||
        (source == LinkSource.unknown && url.startsWith('http'));

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Importer une vidéo depuis un lien',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'Uniquement pour des contenus que tu as le droit d’utiliser '
            '(tes vidéos, banques libres de droits comme Pexels/Pixabay…).',
            style: TextStyle(fontSize: 11.5, color: Colors.white54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            onChanged: (_) => setState(() => _error = null),
            enabled: !_downloading,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Colle le lien ici…',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                tooltip: 'Coller',
                icon: const Icon(Icons.content_paste, size: 18),
                onPressed: _downloading ? null : _pasteFromClipboard,
              ),
            ),
          ),
          if (source != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  downloadable ? Icons.link : Icons.info_outline,
                  size: 16,
                  color: downloadable ? Colors.greenAccent : Colors.amber,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Source détectée : ${source.label}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _sourceHint(source),
              style: const TextStyle(fontSize: 11.5, color: Colors.white60),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style:
                    const TextStyle(fontSize: 12, color: Colors.redAccent)),
          ],
          const SizedBox(height: 12),
          if (_downloading) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 6),
            Text(
              _progress == null
                  ? 'Téléchargement en cours…'
                  : 'Téléchargement : ${(_progress! * 100).round()} %',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ] else
            FilledButton.icon(
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              onPressed:
                  url.isEmpty || !downloadable ? null : _download,
              icon: const Icon(Icons.download),
              label: const Text('Télécharger et ajouter à la séquence'),
            ),
        ],
      ),
    );
  }

  static String _sourceHint(LinkSource source) {
    switch (source) {
      case LinkSource.tiktok:
        return 'TikTok n’offre pas d’API officielle de téléchargement de '
            'vidéos tierces. Si l’auteur l’autorise, utilise « Enregistrer '
            'la vidéo » dans l’app TikTok, puis importe-la depuis ta galerie.';
      case LinkSource.youtube:
        return 'YouTube n’autorise pas le téléchargement hors de ses apps '
            '(sauf YouTube Premium). Pour tes propres vidéos, récupère le '
            'fichier via YouTube Studio, ou utilise un lien direct .mp4.';
      case LinkSource.instagram:
        return 'Instagram n’offre pas d’API officielle de téléchargement de '
            'Reels tiers. Pour tes propres contenus, télécharge-les depuis '
            'l’app Instagram (Paramètres → Télécharger tes données).';
      case LinkSource.direct:
        return 'Fichier vidéo accessible directement : téléchargement dans '
            'la meilleure qualité disponible, sans réencodage.';
      case LinkSource.unknown:
        return 'Lien non reconnu. S’il pointe directement vers un fichier '
            'vidéo, le téléchargement peut être tenté (il sera vérifié).';
    }
  }
}
