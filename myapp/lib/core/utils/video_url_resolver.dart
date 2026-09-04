/// Résultat de la résolution d'une URL vidéo.
///
/// - [isEmbed] == true  -> `url` est une URL d'embed officielle à charger
///   dans une WebView (Facebook, Instagram, TikTok, Google Drive).
/// - [isEmbed] == false -> `url` est un fichier vidéo direct (.mp4/.mov/...)
///   à lire avec media_kit.
class ResolvedVideoSource {
  final bool isEmbed;
  final String url;

  const ResolvedVideoSource({required this.isEmbed, required this.url});
}

/// Détecte la plateforme d'origine d'une URL vidéo et construit, quand
/// c'est possible, l'URL d'embed officielle correspondante.
///
/// Toute URL non reconnue comme provenant d'un réseau social est traitée
/// comme un fichier vidéo direct (typiquement un fichier hébergé sur
/// Supabase Storage ou un autre CDN), à lire via media_kit.
///
/// NOTE : les vidéos YouTube ne passent plus par [resolve] pour l'affichage
/// (voir `_YoutubeThumbnailCard` dans les écrans de détail) : trop de
/// vidéos désactivent la lecture en dehors de YouTube (erreurs 101/150/
/// 152/153), ce qui produisait un rendu cassé/tronqué dans la WebView.
/// On affiche à la place une miniature statique + un bouton qui bascule
/// vers l'app/le site YouTube. [extractYoutubeVideoId] sert à ça.
/// [resolve] reconnaît toujours YouTube au cas où un appelant en aurait
/// besoin, mais les écrans utilisent désormais [extractYoutubeVideoId] en
/// priorité pour router vers la carte miniature.
class VideoUrlResolver {
  VideoUrlResolver._();

  static ResolvedVideoSource resolve(String rawUrl) {
    final url = rawUrl.trim();
    if (url.isEmpty) {
      return ResolvedVideoSource(isEmbed: false, url: url);
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return ResolvedVideoSource(isEmbed: false, url: url);
    }

    final host = uri.host.toLowerCase();

    final youtube = _resolveYoutube(uri, host);
    if (youtube != null) return youtube;

    final facebook = _resolveFacebook(uri, host);
    if (facebook != null) return facebook;

    final instagram = _resolveInstagram(uri, host);
    if (instagram != null) return instagram;

    final tiktok = _resolveTiktok(uri, host);
    if (tiktok != null) return tiktok;

    final drive = _resolveGoogleDrive(uri, host);
    if (drive != null) return drive;

    // Rien de reconnu : on suppose un fichier vidéo direct (mp4, mov, webm,
    // m3u8, etc.), lu par media_kit.
    return ResolvedVideoSource(isEmbed: false, url: url);
  }

  /// Extrait l'ID de vidéo YouTube depuis une URL brute (watch, shorts,
  /// youtu.be, embed, live). Retourne null si l'URL n'est pas une URL
  /// YouTube ou si l'ID n'est pas trouvable.
  ///
  /// Utilisé par les écrans de détail pour router directement vers la
  /// carte miniature YouTube (`_YoutubeThumbnailCard`), sans jamais tenter
  /// de charger l'iframe YouTube dans l'app.
  static String? extractYoutubeVideoId(String rawUrl) {
    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;

    final host = uri.host.toLowerCase();
    final isYoutubeHost = host.contains('youtube.com') || host.contains('youtube-nocookie.com');
    final isShortHost = host == 'youtu.be';
    if (!isYoutubeHost && !isShortHost) return null;

    if (isShortHost) {
      // youtu.be/VIDEO_ID
      final segments = uri.pathSegments;
      return segments.isNotEmpty ? segments.first : null;
    }
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'shorts') {
      // youtube.com/shorts/VIDEO_ID
      return uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
    }
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'embed') {
      // youtube.com/embed/VIDEO_ID
      return uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
    }
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'live') {
      // youtube.com/live/VIDEO_ID
      return uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
    }
    // youtube.com/watch?v=VIDEO_ID
    return uri.queryParameters['v'];
  }

  // ---------------------------------------------------------------------
  // YouTube : youtube.com/watch?v=ID, youtu.be/ID, /shorts/ID, /embed/ID
  // ---------------------------------------------------------------------
  static ResolvedVideoSource? _resolveYoutube(Uri uri, String host) {
    final isYoutubeHost = host.contains('youtube.com') || host.contains('youtube-nocookie.com');
    final isShortHost = host == 'youtu.be';

    if (!isYoutubeHost && !isShortHost) return null;

    String? videoId;

    if (isShortHost) {
      // youtu.be/VIDEO_ID
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) videoId = segments.first;
    } else if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'shorts') {
      // youtube.com/shorts/VIDEO_ID
      if (uri.pathSegments.length > 1) videoId = uri.pathSegments[1];
    } else if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'embed') {
      // Déjà une URL d'embed.
      if (uri.pathSegments.length > 1) videoId = uri.pathSegments[1];
    } else if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'live') {
      // youtube.com/live/VIDEO_ID
      if (uri.pathSegments.length > 1) videoId = uri.pathSegments[1];
    } else {
      // youtube.com/watch?v=VIDEO_ID
      videoId = uri.queryParameters['v'];
    }

    if (videoId == null || videoId.isEmpty) return null;

    return ResolvedVideoSource(
      isEmbed: true,
      url: 'https://www.youtube.com/embed/$videoId?playsinline=1&autoplay=1&rel=0',
    );
  }

  // ---------------------------------------------------------------------
  // Facebook : facebook.com/.../videos/ID, fb.watch/ID
  // ---------------------------------------------------------------------
  static ResolvedVideoSource? _resolveFacebook(Uri uri, String host) {
    final isFacebookHost = host.contains('facebook.com') || host == 'fb.watch';
    if (!isFacebookHost) return null;

    // Le plugin officiel Facebook fonctionne en passant l'URL du post/vidéo
    // (encodée) en paramètre `href`, quelle que soit sa forme exacte.
    final encodedHref = Uri.encodeComponent(uri.toString());

    return ResolvedVideoSource(
      isEmbed: true,
      url: 'https://www.facebook.com/plugins/video.php?href=$encodedHref&show_text=false&autoplay=true',
    );
  }

  // ---------------------------------------------------------------------
  // Instagram : instagram.com/p/CODE, /reel/CODE, /tv/CODE
  // ---------------------------------------------------------------------
  static ResolvedVideoSource? _resolveInstagram(Uri uri, String host) {
    final isInstagramHost = host.contains('instagram.com') || host == 'instagr.am';
    if (!isInstagramHost) return null;

    final segments = uri.pathSegments;
    if (segments.length < 2) return null;

    final kind = segments[0]; // p | reel | tv
    if (kind != 'p' && kind != 'reel' && kind != 'tv') return null;

    final shortcode = segments[1];
    if (shortcode.isEmpty) return null;

    return ResolvedVideoSource(
      isEmbed: true,
      url: 'https://www.instagram.com/$kind/$shortcode/embed/captioned/',
    );
  }

  // ---------------------------------------------------------------------
  // TikTok : tiktok.com/@user/video/ID
  // Les liens courts (vm.tiktok.com/...) ne contiennent pas l'ID directement
  // et nécessitent une redirection réseau pour être résolus : on ne peut pas
  // les convertir de façon fiable ici sans requête HTTP préalable. Dans ce
  // cas on les laisse tomber en "direct" (media_kit échouera proprement et
  // l'utilisateur aura le bouton "Ouvrir dans le navigateur").
  // ---------------------------------------------------------------------
  static ResolvedVideoSource? _resolveTiktok(Uri uri, String host) {
    final isTiktokHost = host.contains('tiktok.com');
    if (!isTiktokHost) return null;

    final segments = uri.pathSegments;
    final videoIndex = segments.indexOf('video');
    if (videoIndex == -1 || videoIndex + 1 >= segments.length) {
      // Lien court (vm.tiktok.com, ou /t/CODE) : pas d'ID exploitable
      // directement, on ne peut pas construire l'embed de façon fiable.
      return null;
    }

    final videoId = segments[videoIndex + 1];
    if (videoId.isEmpty) return null;

    return ResolvedVideoSource(
      isEmbed: true,
      url: 'https://www.tiktok.com/embed/v2/$videoId',
    );
  }

  // ---------------------------------------------------------------------
  // Google Drive : drive.google.com/file/d/ID/view (ou /preview)
  // ---------------------------------------------------------------------
  static ResolvedVideoSource? _resolveGoogleDrive(Uri uri, String host) {
    final isDriveHost = host.contains('drive.google.com');
    if (!isDriveHost) return null;

    final segments = uri.pathSegments;
    final dIndex = segments.indexOf('d');
    String? fileId;

    if (dIndex != -1 && dIndex + 1 < segments.length) {
      fileId = segments[dIndex + 1];
    } else {
      // Format alternatif : drive.google.com/open?id=FILE_ID
      fileId = uri.queryParameters['id'];
    }

    if (fileId == null || fileId.isEmpty) return null;

    return ResolvedVideoSource(
      isEmbed: true,
      url: 'https://drive.google.com/file/d/$fileId/preview',
    );
  }
}