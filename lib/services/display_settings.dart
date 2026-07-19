import 'package:flutter/material.dart';
import '../widgets/theme.dart';
import 'persistence.dart';

/// ─── Réglages d'affichage globaux ────────────────────────────────────────────
/// Mode appareil (Auto / PC / Téléphone), échelle de l'interface et
/// résolution simulée. Singleton observable — tout widget peut s'y abonner.
class DisplaySettings extends ChangeNotifier {
  DisplaySettings._();
  static final DisplaySettings instance = DisplaySettings._();

  /// 'auto' = détection selon la largeur | 'pc' | 'phone'
  String deviceMode = 'auto';

  /// Charge les réglages sauvegardés (à appeler après Prefs.init()).
  void load() {
    final d = Prefs.loadDisplay();
    if (d == null) return;
    deviceMode = d.mode;
    uiScale = d.scale;
    resolutionIdx = d.resIdx;
    notifyListeners();
  }

  void _save() => Prefs.saveDisplay(
      mode: deviceMode, scale: uiScale, resIdx: resolutionIdx);

  /// Échelle de l'interface (taille des textes) : 0.7 → 1.3
  double uiScale = 1.0;

  /// Index de la résolution simulée (voir [resolutions]).
  int resolutionIdx = 5; // Plein écran par défaut

  static const resolutions = [
    DisplayRes('Mobile (390×844)', 390, 844),
    DisplayRes('Tablette (768×1024)', 768, 1024),
    DisplayRes('PC petit (900×600)', 900, 600),
    DisplayRes('PC moyen (1280×800)', 1280, 800),
    DisplayRes('PC grand (1440×900)', 1440, 900),
    DisplayRes('Plein écran', 0, 0), // 0,0 = taille réelle de la fenêtre
  ];

  DisplayRes get resolution => resolutions[resolutionIdx];

  /// Détermine si le layout téléphone doit être utilisé pour une largeur
  /// disponible donnée (celle du LayoutBuilder ou du MediaQuery).
  bool isMobileFor(double width) {
    if (deviceMode == 'phone') return true;
    if (deviceMode == 'pc') return false;
    return width < 600; // auto
  }

  void setDeviceMode(String mode) {
    if (deviceMode == mode) return;
    deviceMode = mode;
    // Confort : passer en mode téléphone propose la résolution mobile,
    // revenir en PC repasse en plein écran (uniquement si l'utilisateur
    // n'a pas déjà choisi autre chose).
    if (mode == 'phone' && resolutionIdx == 5) resolutionIdx = 0;
    if (mode == 'pc' && resolutionIdx == 0) resolutionIdx = 5;
    _save();
    notifyListeners();
  }

  void setUiScale(double v) {
    uiScale = v.clamp(0.7, 1.3);
    _save();
    notifyListeners();
  }

  void setResolutionIdx(int i) {
    if (i < 0 || i >= resolutions.length) return;
    resolutionIdx = i;
    _save();
    notifyListeners();
  }
}

class DisplayRes {
  final String label;
  final int w, h;
  const DisplayRes(this.label, this.w, this.h);
}

/// Panneau de réglages d'affichage — appelable depuis n'importe quel écran.
void showDisplaySettingsSheet(BuildContext ctx) {
  showDialog(context: ctx, builder: (_) => const DisplaySettingsDialog());
}

class DisplaySettingsDialog extends StatefulWidget {
  const DisplaySettingsDialog({super.key});
  @override State<DisplaySettingsDialog> createState() => _DisplaySettingsDialogState();
}

class _DisplaySettingsDialogState extends State<DisplaySettingsDialog> {
  @override
  Widget build(BuildContext ctx) {
    final ds = DisplaySettings.instance;
    return Dialog(
      backgroundColor: kBg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.devices, color: kGold, size: 20),
            const SizedBox(width: 10),
            Text('AFFICHAGE', style: cinzel(15, c: kGold2, fw: FontWeight.w900)),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(ctx),
              child: const Icon(Icons.close, color: kTextSub, size: 20)),
          ]),
          const SizedBox(height: 18),

          Text('APPAREIL', style: cinzel(10, c: kTextSub, ls: 2.0)),
          const SizedBox(height: 8),
          Row(children: [
            _modeChip(ctx, ds, 'auto', Icons.autorenew, 'Auto'),
            const SizedBox(width: 8),
            _modeChip(ctx, ds, 'pc', Icons.desktop_windows, 'PC'),
            const SizedBox(width: 8),
            _modeChip(ctx, ds, 'phone', Icons.smartphone, 'Téléphone'),
          ]),
          const SizedBox(height: 6),
          Text(
            ds.deviceMode == 'auto'
                ? 'Le layout s\'adapte à la largeur de l\'écran.'
                : ds.deviceMode == 'phone'
                    ? 'Layout compact : plateau réduit, joueurs en ligne.'
                    : 'Layout complet du jeu sur grand écran.',
            style: body(10, c: kTextDim)),
          const SizedBox(height: 16),

          Text('ÉCHELLE DE L\'INTERFACE', style: cinzel(10, c: kTextSub, ls: 2.0)),
          Row(children: [
            const Icon(Icons.text_decrease, size: 14, color: kTextDim),
            Expanded(child: Slider(
              value: ds.uiScale, min: 0.7, max: 1.3, divisions: 12,
              activeColor: kGold, inactiveColor: kBord2,
              label: '${(ds.uiScale * 100).round()}%',
              onChanged: (v) { ds.setUiScale(v); setState(() {}); },
            )),
            const Icon(Icons.text_increase, size: 16, color: kTextDim),
            const SizedBox(width: 6),
            SizedBox(width: 38, child: Text('${(ds.uiScale * 100).round()}%',
              style: body(11, c: kGold), textAlign: TextAlign.right)),
          ]),
          const SizedBox(height: 12),

          Text('RÉSOLUTION', style: cinzel(10, c: kTextSub, ls: 2.0)),
          const SizedBox(height: 8),
          ...DisplaySettings.resolutions.asMap().entries.map((e) {
            final selected = e.key == ds.resolutionIdx;
            return GestureDetector(
              onTap: () { ds.setResolutionIdx(e.key); setState(() {}); },
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? kGold.withValues(alpha: 0.12) : kBg3,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? kGold : kBord2),
                ),
                child: Row(children: [
                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 14, color: selected ? kGold : kTextDim),
                  const SizedBox(width: 8),
                  Text(e.value.label, style: body(12, c: selected ? kGold2 : kTextSub)),
                ]),
              ),
            );
          }),
        ])),
      ),
    );
  }

  Widget _modeChip(BuildContext ctx, DisplaySettings ds, String mode,
      IconData icon, String label) {
    final selected = ds.deviceMode == mode;
    return Expanded(child: GestureDetector(
      onTap: () { ds.setDeviceMode(mode); setState(() {}); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kGold.withValues(alpha: 0.14) : kBg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? kGold : kBord2,
            width: selected ? 1.6 : 1),
        ),
        child: Column(children: [
          Icon(icon, size: 18, color: selected ? kGold : kTextDim),
          const SizedBox(height: 4),
          Text(label, style: cinzel(9, c: selected ? kGold2 : kTextSub)),
        ]),
      ),
    ));
  }
}

