import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoCacheManager {
  VideoCacheManager._();

  static final Map<String, _CachedVideoEntry> _cache = {};
  static const int _maxEntries = 8;
  static const Duration _openTimeout = Duration(seconds: 15);

  static Future<VideoController> getController(String url, {String? scope}) async {
    var entry = _cache[url];

    if (entry == null) {
      final player = Player();
      final videoController = VideoController(player);
      entry = _CachedVideoEntry(
        url: url,
        player: player,
        videoController: videoController,
      );
      entry.openFuture = _openWithReadyCheck(player, url);
      _cache[url] = entry;
    }

    entry.addRef(scope);
    _trimCacheIfNeeded(excludeUrl: url);

    if (entry.openFuture != null) {
      try {
        await entry.openFuture;
      } catch (error) {
        // L'ouverture a échoué ou a expiré : on retire l'entrée cassée
        // du cache pour qu'un nouvel essai (bouton "Réessayer") reparte propre.
        entry.removeRef(scope);
        _cache.remove(url);
        entry.player.dispose();
        rethrow;
      }
    }

    return entry.videoController;
  }

  /// Ouvre le média et attend un signal fiable de "prêt à jouer"
  /// (durée connue) ou une erreur explicite, avec un délai maximum.
  static Future<void> _openWithReadyCheck(Player player, String url) async {
    final completer = Completer<void>();
    late final StreamSubscription errorSub;
    late final StreamSubscription durationSub;

    errorSub = player.stream.error.listen((message) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Erreur lecteur: $message'));
      }
    });

    durationSub = player.stream.duration.listen((duration) {
      if (duration > Duration.zero && !completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      // Lance l'ouverture en parallèle de l'écoute ci-dessus.
      unawaited(player.open(Media(url), play: false));

      await completer.future.timeout(
        _openTimeout,
        onTimeout: () {
          throw Exception('Délai dépassé : la vidéo met trop de temps à charger.');
        },
      );
    } finally {
      await errorSub.cancel();
      await durationSub.cancel();
    }
  }

  static void releaseController(String url, {String? scope}) {
    final entry = _cache[url];
    if (entry == null) return;

    entry.removeRef(scope);

    if (entry.hasNoRefs) {
      _cache.remove(url);
      entry.player.dispose();
    }
  }

  static void clearScope(String scope) {
    final entries = _cache.values.toList();

    for (final entry in entries) {
      entry.removeScope(scope);

      if (entry.hasNoRefs) {
        _cache.remove(entry.url);
        entry.player.dispose();
      }
    }
  }

  static void clear() {
    for (final entry in _cache.values) {
      entry.player.dispose();
    }
    _cache.clear();
  }

  static void _trimCacheIfNeeded({String? excludeUrl}) {
    if (_cache.length <= _maxEntries) return;

    for (final entry in _cache.values.toList()) {
      if (_cache.length <= _maxEntries) break;
      if (entry.url == excludeUrl) continue;
      if (entry.hasNoRefs) {
        _cache.remove(entry.url);
        entry.player.dispose();
      }
    }
  }
}

class _CachedVideoEntry {
  _CachedVideoEntry({
    required this.url,
    required this.player,
    required this.videoController,
  });

  final String url;
  final Player player;
  final VideoController videoController;
  Future<void>? openFuture;
  int _globalRefs = 0;
  final Map<String, int> _scopeRefs = <String, int>{};

  void addRef(String? scope) {
    if (scope != null && scope.isNotEmpty) {
      _scopeRefs[scope] = (_scopeRefs[scope] ?? 0) + 1;
    } else {
      _globalRefs += 1;
    }
  }

  void removeRef(String? scope) {
    if (scope != null && scope.isNotEmpty) {
      final current = _scopeRefs[scope] ?? 0;
      if (current <= 1) {
        _scopeRefs.remove(scope);
      } else {
        _scopeRefs[scope] = current - 1;
      }
    } else {
      if (_globalRefs > 0) {
        _globalRefs -= 1;
      }
    }
  }

  void removeScope(String scope) {
    if (scope.isEmpty) return;
    _scopeRefs.remove(scope);
  }

  bool get hasNoRefs => _globalRefs == 0 && _scopeRefs.values.every((count) => count == 0);
}