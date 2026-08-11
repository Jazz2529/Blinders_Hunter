// lib/data/tokens_data.dart
// Données des jetons joueurs — 19 jetons PNG
// IDs = noms (en minuscules)

import '../services/persistence.dart';
import 'cosmetics_data.dart';

class TokenData {
  final String id;
  final String name;
  final String imagePath;
  final String fallbackEmoji;
  const TokenData({required this.id, required this.name,
    required this.imagePath, required this.fallbackEmoji});
}

const List<TokenData> kAllTokens = [
  TokenData(id:'vlad',     name:'Vlad',     imagePath:'assets/images/tokens/jeton1.png',  fallbackEmoji:'⚪'),
  TokenData(id:'cambou',   name:'Cambou',   imagePath:'assets/images/tokens/jeton6.png',  fallbackEmoji:'⚪'),
  TokenData(id:'marin',    name:'Marin',    imagePath:'assets/images/tokens/jeton3.png',  fallbackEmoji:'⚪'),
  TokenData(id:'albane',   name:'Albane',   imagePath:'assets/images/tokens/jeton9.png',  fallbackEmoji:'🟡'),
  TokenData(id:'raph',     name:'Raph',     imagePath:'assets/images/tokens/jeton10.png', fallbackEmoji:'🟡'),
  TokenData(id:'marion',   name:'Marion',   imagePath:'assets/images/tokens/jeton8.png',  fallbackEmoji:'🔴'),
  TokenData(id:'nils',     name:'Nils',     imagePath:'assets/images/tokens/jeton21.png', fallbackEmoji:'🔴'),
  TokenData(id:'peio',     name:'Peio',     imagePath:'assets/images/tokens/jeton15.png', fallbackEmoji:'🟣'),
  TokenData(id:'remi',     name:'Remi',     imagePath:'assets/images/tokens/jeton14.png', fallbackEmoji:'🟣'),
  TokenData(id:'julien',   name:'Julien',   imagePath:'assets/images/tokens/jeton5.png',  fallbackEmoji:'🟣'),
  TokenData(id:'jason',    name:'Jason',    imagePath:'assets/images/tokens/jeton2.png',  fallbackEmoji:'🔵'),
  TokenData(id:'damien',   name:'Damien',   imagePath:'assets/images/tokens/jeton12.png', fallbackEmoji:'🔵'),
  TokenData(id:'clemence', name:'Clemence', imagePath:'assets/images/tokens/jeton13.png', fallbackEmoji:'🟢'),
  TokenData(id:'carla',    name:'Carla',    imagePath:'assets/images/tokens/jeton7.png',  fallbackEmoji:'🟢'),
  TokenData(id:'elise',    name:'Elise',    imagePath:'assets/images/tokens/jeton16.png', fallbackEmoji:'🟢'),
  TokenData(id:'emilien',  name:'Emilien',  imagePath:'assets/images/tokens/jeton11.png', fallbackEmoji:'🟡'),
  TokenData(id:'felipe',   name:'Felipe',   imagePath:'assets/images/tokens/jeton4.png',  fallbackEmoji:'🟡'),
  TokenData(id:'elaia',    name:'Elaia',    imagePath:'assets/images/tokens/jeton22.png', fallbackEmoji:'🔴'),
  TokenData(id:'toph',     name:'Toph',     imagePath:'assets/images/tokens/jeton19.png', fallbackEmoji:'🦀'),
  TokenData(id:'bingbong', name:'Bingbong', imagePath:'assets/images/tokens/jeton17.png', fallbackEmoji:'⚪'),
  TokenData(id:'conan',    name:'Conan',    imagePath:'assets/images/tokens/jeton18.png', fallbackEmoji:'🔍'),
  TokenData(id:'flott',    name:'Flott',    imagePath:'assets/images/tokens/jeton20.png', fallbackEmoji:'🏄'),
];

TokenData? findToken(String id) {
  try { return kAllTokens.firstWhere((t) => t.id == id); } catch (_) {
    // Peut-être un jeton cosmétique (débloqué en boutique) plutôt qu'un
    // jeton de base — on le convertit à la volée au même format.
    final item = kCosmeticsCatalog.where((c) =>
        c.category == CosmeticCategory.token && c.id == id).firstOrNull;
    if (item != null) {
      return TokenData(id: item.id, name: item.name,
        imagePath: item.imagePath, fallbackEmoji: item.fallbackEmoji);
    }
    return null;
  }
}

/// Tous les jetons que le joueur peut choisir : les jetons de base, PLUS
/// les jetons cosmétiques qu'il a débloqués en boutique — ajoutés à la
/// liste, pas en remplacement d'un jeton existant.
List<TokenData> availableTokens() {
  final owned = Prefs.ownedCosmetics();
  final cosmeticTokens = kCosmeticsCatalog
      .where((c) => c.category == CosmeticCategory.token && owned.contains(c.id))
      .map((c) => TokenData(id: c.id, name: c.name,
          imagePath: c.imagePath, fallbackEmoji: c.fallbackEmoji));
  return [...kAllTokens, ...cosmeticTokens];
}

/// Illustration effective d'un jeton — fonctionne aussi bien pour un jeton
/// de base que pour un jeton cosmétique débloqué en boutique (les deux
/// sont résolus par findToken(), qui vérifie les deux catalogues).
String effectiveTokenImagePath(String tokenId) => findToken(tokenId)?.imagePath ?? '';
