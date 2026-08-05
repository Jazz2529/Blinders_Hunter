// lib/widgets/token_widget.dart
// Widget jeton — affiche l'image PNG ou un fallback

import 'package:flutter/material.dart';
import '../data/tokens_data.dart';
import 'theme.dart';

class TokenWidget extends StatelessWidget {
  final String tokenId;   // ex: 'vlad', 'jason', etc.
  final double size;
  final bool selected;
  final bool showName;
  final bool isDead;

  const TokenWidget({
    super.key,
    required this.tokenId,
    this.size = 44,
    this.selected = false,
    this.showName = false,
    this.isDead = false,
  });

  @override
  Widget build(BuildContext context) {
    final token = findToken(tokenId);
    if (token == null) {
      // Fallback si le token n'existe pas
      return _buildFallback(tokenId);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? kGold2 : Colors.transparent,
              width: selected ? 2.5 : 0,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(color: kGold.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 1),
              if (!isDead)
                // Ombre portée franche, projetée d'un seul côté (bas-droite)
                // — comme un vrai jeton posé sur le plateau, éclairé d'en
                // haut à gauche. Beaucoup plus marquée que la version
                // précédente (opacité et décalage nettement augmentés).
                BoxShadow(color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: size * 0.14, spreadRadius: 0,
                  offset: Offset(size * 0.11, size * 0.14)),
            ],
          ),
          child: Opacity(
            opacity: isDead ? 0.35 : 1.0,
            child: ClipOval(
              child: Image.asset(
                token.imagePath,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // IMPORTANT : sans cacheWidth/cacheHeight, Flutter décode
                // l'image à sa résolution SOURCE complète en mémoire, même
                // pour un petit jeton affiché à l'écran — si les fichiers
                // sources sont en haute résolution, ça peut faire échouer
                // silencieusement le chargement sur un appareil à RAM
                // limitée (émulateur) alors que ça passe sans souci sur PC.
                cacheWidth: (size * 3).round(),
                cacheHeight: (size * 3).round(),
                errorBuilder: (_, __, ___) => _buildFallback(token.fallbackEmoji),
              ),
            ),
          ),
        ),
        if (showName) ...[
          const SizedBox(height: 3),
          Text(
            token.name,
            style: cinzel(9, c: selected ? kGold2 : kTextSub),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildFallback(String text) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: kBg3,
      border: Border.all(color: selected ? kGold2 : kBord2, width: 1.5),
    ),
    child: Center(
      child: Text(text, style: TextStyle(fontSize: size * 0.45)),
    ),
  );
}

// ─── Sélecteur de jeton (écran d'accueil) ────────────────

class TokenPicker extends StatelessWidget {
  final String selectedId;
  final void Function(String id) onSelect;

  const TokenPicker({
    super.key,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: kAllTokens.map((token) {
        final sel = selectedId == token.id;
        return GestureDetector(
          onTap: () => onSelect(token.id),
          child: Tooltip(
            message: token.name,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: sel ? kGold2 : Colors.transparent,
                  width: sel ? 2.5 : 0),
                boxShadow: sel ? [
                  BoxShadow(color: kGold.withValues(alpha: 0.5),
                    blurRadius: 8, spreadRadius: 1),
                ] : null,
              ),
              child: ClipOval(
                child: Image.asset(
                  token.imagePath,
                  fit: BoxFit.cover,
                  cacheWidth: 114, // 38 * 3 — voir TokenWidget pour l'explication
                  cacheHeight: 114,
                  errorBuilder: (_, __, ___) => Container(
                    color: kBg3,
                    child: Center(child: Text(token.fallbackEmoji,
                      style: const TextStyle(fontSize: 16)))),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
