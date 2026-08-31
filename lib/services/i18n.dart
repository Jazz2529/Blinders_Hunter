// lib/services/i18n.dart
// ─── Système de langue ────────────────────────────────────────────────────
// Réglage observable (français/anglais), mémorisé d'une session à l'autre.
// Le contenu de jeu (personnages, cartes, terrains) est traduit via des
// tables de correspondance dans lib/data/translations_*.dart — voir tr()
// plus bas pour l'utilisation. Le reste de l'interface (menus, boutons,
// dialogues) utilise ui() avec des clés courtes, définies ci-dessous.
import 'package:flutter/material.dart';
import 'persistence.dart';
import '../data/translations_data.dart';

class AppLanguage extends ChangeNotifier {
  AppLanguage._();
  static final AppLanguage instance = AppLanguage._();

  /// 'fr' ou 'en'
  String code = 'fr';

  void load() {
    code = Prefs.language();
    notifyListeners();
  }

  void setLanguage(String value) {
    if (code == value) return;
    code = value;
    Prefs.setLanguage(value);
    notifyListeners();
  }

  bool get isEnglish => code == 'en';
}

/// Traduit un texte de CONTENU DE JEU (nom/capacité de personnage, texte de
/// carte, description de terrain...) — cherche `original` dans la table de
/// correspondance ; si l'anglais est actif ET qu'une traduction existe, la
/// renvoie, sinon renvoie le texte original tel quel (repli sûr : jamais de
/// texte manquant, même pour du contenu pas encore traduit).
String tr(String original) {
  if (!AppLanguage.instance.isEnglish) return original;
  return kGameTranslations[original] ?? original;
}

/// Traduit un élément d'INTERFACE (bouton, titre, libellé...) par clé
/// courte plutôt que par le texte français complet — plus stable si le
/// texte français est amené à changer légèrement par la suite.
String ui(String key) {
  if (!AppLanguage.instance.isEnglish) return kUiStringsFr[key] ?? key;
  return kUiStringsEn[key] ?? kUiStringsFr[key] ?? key;
}

/// Enveloppe un écran pour qu'il se reconstruise IMMÉDIATEMENT dès que la
/// langue change — nécessaire pour tout écran ouvert via Navigator.push
/// (configuration solo, règles, stats, boutique, catalogue...), qui ne
/// profite PAS automatiquement de la reconstruction globale déclenchée
/// depuis _RootWrapper (celle-ci ne rebâtit que l'écran racine — accueil/
/// lobby/jeu —, pas les écrans empilés séparément par le Navigator).
class LanguageAware extends StatefulWidget {
  final WidgetBuilder builder;
  const LanguageAware({super.key, required this.builder});
  @override
  State<LanguageAware> createState() => _LanguageAwareState();
}
class _LanguageAwareState extends State<LanguageAware> {
  @override
  void initState() {
    super.initState();
    AppLanguage.instance.addListener(_onChange);
  }
  @override
  void dispose() {
    AppLanguage.instance.removeListener(_onChange);
    super.dispose();
  }
  void _onChange() { if (mounted) setState(() {}); }
  @override
  Widget build(BuildContext context) => widget.builder(context);
}
