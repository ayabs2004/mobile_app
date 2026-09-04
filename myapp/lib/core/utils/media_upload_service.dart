import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:get_video_thumbnail/get_video_thumbnail.dart';
import 'package:get_video_thumbnail/index.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Résultat d'un upload de média vers Supabase Storage.
class MediaUploadResult {
  final String url;
  final String storagePath;
  final String? thumbnailUrl;

  const MediaUploadResult({
    required this.url,
    required this.storagePath,
    this.thumbnailUrl,
  });
}

/// Service permettant d'ajouter une vidéo depuis le téléphone de
/// l'utilisateur (galerie ou caméra) comme source de média, en plus des
/// liens YouTube/Facebook/Instagram/TikTok/Google Drive déjà gérés par
/// [VideoUrlResolver].
///
/// Le fichier est envoyé vers le bucket Supabase Storage `media`, puis son
/// URL publique est enregistrée dans la table `media` (même table lue par
/// les écrans de détail coach/joueur). Cette URL Supabase ne correspondant
/// à aucun réseau social connu, elle sera automatiquement traitée comme un
/// "fichier vidéo direct" et lue via media_kit — aucune modification des
/// écrans de détail n'est nécessaire.
///
/// En plus de la vidéo, une miniature (JPEG, une frame extraite) est
/// générée et uploadée à côté, pour affichage en aperçu avant lecture dans
/// les écrans publics (au lieu du dégradé générique). La génération est
/// non bloquante : si elle échoue, l'upload/la génération vidéo reste
/// utilisable, simplement sans miniature.
class MediaUploadService {
  MediaUploadService._();

  static final ImagePicker _picker = ImagePicker();

  static const String _storageBucket = 'media';

  /// Ouvre la galerie du téléphone et laisse l'utilisateur choisir une
  /// vidéo. Retourne `null` si l'utilisateur annule.
  static Future<XFile?> pickVideoFromGallery() {
    return _picker.pickVideo(source: ImageSource.gallery);
  }

  /// Alternative : filmer directement une vidéo avec la caméra.
  static Future<XFile?> recordVideo({Duration? maxDuration}) {
    return _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: maxDuration ?? const Duration(minutes: 5),
    );
  }

  /// Ouvre la galerie du téléphone et laisse l'utilisateur choisir une
  /// photo. Retourne `null` si l'utilisateur annule.
  static Future<XFile?> pickImageFromGallery() {
    return _picker.pickImage(source: ImageSource.gallery);
  }

  /// Alternative : prendre directement une photo avec la caméra.
  static Future<XFile?> takePhoto() {
    return _picker.pickImage(source: ImageSource.camera);
  }

  /// Upload le fichier image vers le bucket Supabase Storage `media`
  /// et retourne l'URL publique.
  static Future<MediaUploadResult> uploadImage({
    required XFile image,
    required String entityType,
    required String entityId,
  }) async {
    final Uint8List bytes = await image.readAsBytes();
    final fileExt = image.path.contains('.') ? image.path.split('.').last : 'jpg';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final storagePath = '$entityType/$entityId/$fileName';

    String contentType = 'image/jpeg';
    final lowerExt = fileExt.toLowerCase();
    if (lowerExt == 'png') {
      contentType = 'image/png';
    } else if (lowerExt == 'gif') {
      contentType = 'image/gif';
    } else if (lowerExt == 'webp') {
      contentType = 'image/webp';
    }

    await SupabaseConfig.client.storage.from(_storageBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    final publicUrl =
        SupabaseConfig.client.storage.from(_storageBucket).getPublicUrl(storagePath);

    return MediaUploadResult(
      url: publicUrl,
      storagePath: storagePath,
    );
  }

  /// Upload le fichier vidéo vers le bucket Supabase Storage `media`,
  /// génère et uploade sa miniature, et retourne les deux URLs publiques.
  ///
  /// [entityType] : 'coach' ou 'player'.
  /// [entityId]   : id du coach/joueur concerné.
  static Future<MediaUploadResult> uploadVideo({
    required XFile video,
    required String entityType,
    required String entityId,
  }) async {
    final Uint8List bytes = await video.readAsBytes();
    final fileExt = video.path.contains('.') ? video.path.split('.').last : 'mp4';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final storagePath = '$entityType/$entityId/$fileName';

    await SupabaseConfig.client.storage.from(_storageBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'video/mp4',
            upsert: false,
          ),
        );

    final publicUrl =
        SupabaseConfig.client.storage.from(_storageBucket).getPublicUrl(storagePath);

    // --- Génération + upload de la miniature (non bloquant) ---
    String? thumbnailUrl;
    try {
      final thumbBytes = await VideoThumbnail.thumbnailData(
        video: video.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 70,
        timeMs: 500, // évite les 1res frames souvent noires
      );

      if (thumbBytes != null) {
        thumbnailUrl = await _uploadThumbnailBytes(
          thumbBytes,
          entityType: entityType,
          entityId: entityId,
        );
      }
    } catch (e) {
      debugPrint('Génération miniature (upload téléphone) échouée : $e');
      // Non bloquant : l'upload vidéo reste valide sans miniature.
    }

    return MediaUploadResult(
      url: publicUrl,
      storagePath: storagePath,
      thumbnailUrl: thumbnailUrl,
    );
  }

  /// Génère une miniature à partir d'une URL vidéo DIRECTE déjà en ligne
  /// (lien collé manuellement, pas un upload depuis le téléphone) et
  /// l'uploade vers le storage. Ne doit être appelé QUE pour des fichiers
  /// vidéo directs (.mp4/.mov/...), jamais pour YouTube ou un embed réseau
  /// social — c'est à l'appelant de filtrer via
  /// `VideoUrlResolver.extractYoutubeVideoId` / `resolve(...).isEmbed`
  /// avant d'appeler cette méthode.
  ///
  /// Retourne `null` en cas d'échec (dégradation gracieuse, non bloquant) :
  /// certains hébergeurs bloquent les requêtes cross-origin/anti-hotlink
  /// sur leurs fichiers, ce qui fera échouer silencieusement l'extraction.
  static Future<String?> generateThumbnailForUrl({
    required String videoUrl,
    required String entityType,
    required String entityId,
  }) async {
    try {
      final thumbBytes = await VideoThumbnail.thumbnailData(
        video: videoUrl, // video_thumbnail supporte les URLs http(s)
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 70,
        timeMs: 500,
      );

      if (thumbBytes == null) return null;

      return await _uploadThumbnailBytes(
        thumbBytes,
        entityType: entityType,
        entityId: entityId,
      );
    } catch (e) {
      debugPrint('Génération miniature (URL) échouée : $e');
      return null;
    }
  }

  /// Upload des octets JPEG de miniature vers le storage et retourne l'URL
  /// publique. Factorisé entre [uploadVideo] et [generateThumbnailForUrl].
  static Future<String> _uploadThumbnailBytes(
    Uint8List thumbBytes, {
    required String entityType,
    required String entityId,
  }) async {
    final thumbPath =
        '$entityType/$entityId/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await SupabaseConfig.client.storage.from(_storageBucket).uploadBinary(
          thumbPath,
          thumbBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
        );

    return SupabaseConfig.client.storage.from(_storageBucket).getPublicUrl(thumbPath);
  }

  /// Insère la ligne correspondante dans la table `media`, avec le même
  /// schéma que celui lu par `PlayerMediaItem.fromJson` dans les écrans de
  /// détail (entity_type, entity_id, media_type, url, thumbnail_url,
  /// caption, is_cover, display_order).
  static Future<void> insertVideoRow({
    required String entityType,
    required String entityId,
    required String url,
    String? thumbnailUrl,
    String? caption,
    int displayOrder = 0,
  }) async {
    await SupabaseConfig.client.from('media').insert({
      'entity_type': entityType,
      'entity_id': entityId,
      'media_type': 'video',
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'caption': caption,
      'is_cover': false,
      'display_order': displayOrder,
    });
  }

  /// Supprime un fichier du Storage (utile si l'insertion en base échoue
  /// après un upload réussi, pour ne pas laisser de fichier orphelin).
  static Future<void> deleteUploadedFile(String storagePath) async {
    await SupabaseConfig.client.storage.from(_storageBucket).remove([storagePath]);
  }
}