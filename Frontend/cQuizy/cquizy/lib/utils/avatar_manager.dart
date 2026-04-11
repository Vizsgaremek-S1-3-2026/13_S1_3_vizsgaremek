class AvatarManager {
  static const Map<String, String> _avatarUrls = {
    'avatar_1': 'https://i.kek.sh/lqHYrTjF5BX.png',
    'avatar_2': 'https://i.kek.sh/ilf5cclAW48.png',
    'avatar_3': 'https://i.kek.sh/pDJXNyMdl6f.png',
    'avatar_4': 'https://i.kek.sh/SQg2UoyZeWe.png',
    'avatar_5': 'https://i.kek.sh/lPfMtku7VuM.png',
    'avatar_6': 'https://i.kek.sh/qr2FXinJGRS.png',
    'avatar_7': 'https://i.kek.sh/A2M9tIGJj1T.png',
    'avatar_8': 'https://i.kek.sh/vEoQBloamQY.png',
    'avatar_9': 'https://i.kek.sh/aJ7vm5SdIX3.png',
    'avatar_10': 'https://i.kek.sh/pSZFO8o8CaP.png',
  };

  /// Returns the corresponding image URL for a given avatar ID.
  /// If the ID is not found, it returns the input string itself (assuming it's a direct URL or null).
  static String? getAvatarUrl(String? id) {
    if (id == null) return null;
    if (_avatarUrls.containsKey(id)) {
      return _avatarUrls[id];
    }
    // Check if it looks like a URL
    if (id.startsWith('http') || id.startsWith('assets/')) {
      return id;
    }
    return null; // Fallback for unknown IDs that aren't URLs
  }

  /// Returns a centralized list of avatar data for the selectors.
  static List<Map<String, dynamic>> getAvatars() {
    return _avatarUrls.entries.map((entry) {
      return {
        'id': entry.key,
        'url': entry.value,
        'category': 'Figurák', // Minden jelenlegi avatar ebbe a kategóriába kerül
      };
    }).toList();
  }

  /// Helper to check if a string is a mapped avatar ID
  static bool isAvatarId(String? value) {
    return value != null && _avatarUrls.containsKey(value);
  }
}
