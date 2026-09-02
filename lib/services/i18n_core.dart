// lib/services/i18n_core.dart
// Noyau du système de langue SANS dépendance Flutter — utilisable depuis
// engine.dart (moteur de jeu pur), contrairement à services/i18n.dart (qui
// dépend de Flutter pour ChangeNotifier/Widget et reste la référence pour
// TOUT LE RESTE de l'application). `services/i18n.dart` synchronise
// `isEnglishCore` à chaque changement de langue — voir AppLanguage.
import '../data/translations_data.dart';

bool isEnglishCore = false;

/// Traduit un texte de CONTENU DE JEU — voir tr() dans services/i18n.dart
/// pour la documentation complète (même comportement, sans dépendance
/// Flutter, pour un usage depuis le moteur pur).
String trCore(String original) {
  if (!isEnglishCore) return original;
  return kGameTranslations[original] ?? original;
}

// Marqueurs (caractères de la zone d'usage privé Unicode, jamais utilisés
// dans du texte normal) délimitant un message de journal "brut" — voir
// logTCore()/resolveLogCore() ci-dessous. Un marqueur de FIN explicite est
// nécessaire car plusieurs segments bruts peuvent être concaténés entre eux
// (ou avec du texte littéral, ex: séparateur ' | ') dans un même message —
// sans lui, impossible de savoir où un segment s'arrête et où le suivant
// (ou du texte simple) commence.
const String _kLogRawMarker = '\uE000';
const String _kLogPairSep = '\uE001';
const String _kLogKvSep = '\uE002';
const String _kLogEndMarker = '\uE003';

/// IMPORTANT — historique du bug corrigé ici : logTCore() traduisait
/// auparavant IMMÉDIATEMENT le message (selon la langue de l'appareil qui
/// vient de jouer l'action), puis ce texte déjà traduit était stocké tel
/// quel dans le journal partagé (Firebase, en multijoueur). Résultat : TOUS
/// les joueurs voyaient le journal dans la langue de celui qui avait
/// déclenché chaque message, pas dans LEUR PROPRE langue.
///
/// Corrigé en stockant à la place le GABARIT BRUT (template + paramètres),
/// encodé avec des marqueurs Unicode dédiés — la traduction ne se fait plus
/// ici, mais à l'AFFICHAGE, sur CHAQUE appareil séparément, via
/// resolveLogCore() — voir ce nom dans le journal. Peut être concaténé
/// librement avec du texte littéral ou d'autres segments logTCore() (grâce
/// au marqueur de fin), resolveLogCore() les résout tous correctement.
String logTCore(String template, Map<String, String> params) {
  final buf = StringBuffer(_kLogRawMarker)..write(template);
  params.forEach((k, v) {
    buf.write(_kLogPairSep);
    buf.write(k);
    buf.write(_kLogKvSep);
    buf.write(v);
  });
  buf.write(_kLogEndMarker);
  return buf.toString();
}

/// Résout un message de journal — remplace CHAQUE segment brut (produit par
/// logTCore(), délimité par ses marqueurs) par sa traduction selon la
/// langue ACTUELLE de CET appareil, en laissant intact tout texte littéral
/// autour (séparateurs, texte non passé par logT, anciens messages
/// d'avant ce correctif...). À appeler à chaque AFFICHAGE d'une entrée de
/// journal, jamais au moment de sa création.
String resolveLogCore(String raw) {
  if (!raw.contains(_kLogRawMarker)) return raw;
  final buf = StringBuffer();
  int i = 0;
  while (i < raw.length) {
    final start = raw.indexOf(_kLogRawMarker, i);
    if (start < 0) { buf.write(raw.substring(i)); break; }
    buf.write(raw.substring(i, start));
    final end = raw.indexOf(_kLogEndMarker, start);
    if (end < 0) { buf.write(raw.substring(start)); break; } // marqueur de fin manquant (ne devrait pas arriver) : on abandonne proprement
    final segment = raw.substring(start + _kLogRawMarker.length, end);
    final parts = segment.split(_kLogPairSep);
    final template = parts.first;
    String result = isEnglishCore
        ? (kLogTemplatesEn[template] ?? template)
        : template;
    for (final pair in parts.skip(1)) {
      final sepIdx = pair.indexOf(_kLogKvSep);
      if (sepIdx < 0) continue;
      final k = pair.substring(0, sepIdx);
      // IMPORTANT : trCore() appliqué ICI (pas à la création) à CHAQUE
      // valeur de paramètre — un nom de personnage/objet inséré dans un
      // message doit lui aussi être traduit selon la langue du SPECTATEUR
      // actuel, pas celle de l'auteur du message. Sans danger pour les
      // valeurs qui n'ont pas besoin de traduction (noms de joueurs,
      // nombres...) : trCore() les renvoie alors inchangées.
      final v = trCore(pair.substring(sepIdx + _kLogKvSep.length));
      result = result.replaceAll('{$k}', v);
    }
    buf.write(result);
    i = end + _kLogEndMarker.length;
  }
  return buf.toString();
}
