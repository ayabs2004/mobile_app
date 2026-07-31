import 'package:flutter/foundation.dart';

/// Centralise la transformation des erreurs techniques (exceptions Supabase,
/// erreurs réseau, etc.) en messages compréhensibles et non sensibles pour
/// l'utilisateur final.
///
/// Le détail technique complet n'est JAMAIS affiché à l'écran en production :
/// il est seulement journalisé via [debugPrint], donc visible uniquement
/// dans les logs de développement (kDebugMode).
class ErrorUtils {
  ErrorUtils._();

  /// Message générique et sûr à afficher dans l'UI (SnackBar, écran d'erreur…).
  ///
  /// [context] est un court libellé optionnel (ex: "chargement des joueurs")
  /// pour légèrement adapter le message sans jamais exposer l'exception brute.
  static String friendlyMessage(Object error, {String? context}) {
    if (kDebugMode) {
      debugPrint('[ErrorUtils] ${context ?? ''}: $error');
    }

    final description = context != null && context.isNotEmpty
        ? 'lors de $context'
        : null;

    return description != null
        ? "Une erreur est survenue $description. Merci de réessayer."
        : "Une erreur est survenue. Merci de réessayer dans quelques instants.";
  }
}
