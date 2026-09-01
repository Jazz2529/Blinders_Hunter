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

/// Traduit un MESSAGE DE JOURNAL construit dynamiquement à partir d'un
/// gabarit — voir logT() dans services/i18n.dart pour la documentation
/// complète.
String logTCore(String template, Map<String, String> params) {
  String result = isEnglishCore
      ? (kLogTemplatesEn[template] ?? template)
      : template;
  params.forEach((k, v) => result = result.replaceAll('{$k}', v));
  return result;
}
