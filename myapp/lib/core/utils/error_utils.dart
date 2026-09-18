import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralise la transformation des erreurs techniques (exceptions Supabase,
/// erreurs réseau, etc.) en messages compréhensibles et non sensibles pour
/// l'utilisateur final.
class ErrorUtils {
  ErrorUtils._();

  /// Message clair et sûr à afficher dans l'UI (SnackBar, écran d'erreur…).
  ///
  /// [ctx] est un court libellé optionnel (ex: "chargement des joueurs")
  /// pour adapter le message sans jamais exposer l'exception brute.
  static String friendlyMessage(Object error, {String? context, String? ctx}) {
    final label = ctx ?? context;
    if (kDebugMode) {
      debugPrint('[ErrorUtils] ${label ?? ''}: $error');
    }

    final msg = _classify(error);
    if (label != null && label.isNotEmpty) {
      return '$msg ($label)';
    }
    return msg;
  }

  static String _classify(Object error) {
    // Erreurs Supabase
    if (error is PostgrestException) {
      final code = error.code ?? '';
      final details = (error.details ?? '').toString().toLowerCase();
      final message = error.message.toLowerCase();

      if (code == '23505' || message.contains('duplicate') || details.contains('unique')) {
        return 'Un enregistrement identique existe déjà. Vérifiez les informations saisies.';
      }
      if (code == '23503' || message.contains('foreign key')) {
        return 'Impossible : cet élément est encore utilisé ailleurs dans l\'application.';
      }
      if (code == '42501' || message.contains('permission') || message.contains('denied')) {
        return 'Vous n\'avez pas les droits pour effectuer cette action.';
      }
      if (code == '22P02' || message.contains('invalid input syntax')) {
        return 'Les données saisies sont invalides. Vérifiez les champs et réessayez.';
      }
      if (code == 'PGRST301' || message.contains('jwt')) {
        return 'Votre session a expiré. Veuillez vous reconnecter.';
      }
      if (message.contains('not found') || code == 'PGRST116') {
        return 'L\'élément demandé est introuvable.';
      }
      return 'Une erreur de base de données est survenue. Réessayez dans quelques instants.';
    }

    // Erreurs d'authentification Supabase
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login') || msg.contains('wrong password') || msg.contains('invalid credentials')) {
        return 'Email ou mot de passe incorrect.';
      }
      if (msg.contains('email not confirmed')) {
        return 'Veuillez confirmer votre adresse email avant de vous connecter.';
      }
      if (msg.contains('user not found')) {
        return 'Aucun compte trouvé avec cet email.';
      }
      if (msg.contains('email already')) {
        return 'Un compte existe déjà avec cet email.';
      }
      if (msg.contains('session')) {
        return 'Votre session a expiré. Veuillez vous reconnecter.';
      }
      return 'Erreur d\'authentification. Vérifiez vos informations et réessayez.';
    }

    // Erreurs réseau
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('socketexception') ||
        errStr.contains('connection refused') ||
        errStr.contains('network') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('no internet')) {
      return 'Impossible de se connecter au serveur. Vérifiez votre connexion internet.';
    }
    if (errStr.contains('timeout') || errStr.contains('timed out')) {
      return 'La connexion a pris trop de temps. Réessayez dans quelques instants.';
    }
    if (errStr.contains('formatexception') || errStr.contains('unexpected character')) {
      return 'Les données reçues sont invalides. Réessayez ou contactez le support.';
    }

    return 'Une erreur est survenue. Réessayez dans quelques instants.';
  }
}
