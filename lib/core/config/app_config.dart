/// Central configuration — ad unit IDs, feature flags, IAP product IDs.
/// Swap test IDs to live IDs before store submission.
import 'dart:io';

class AppConfig {
  AppConfig._();

  // ── IAP ──────────────────────────────────────────────────────────────────
  static const String removeAdsSku = 'com.sportsrostering.app.remove_ads';

  // ── AdMob ─────────────────────────────────────────────────────────────────
  // LIVE App IDs (production)
  static const String admobAppIdAndroid =
      'ca-app-pub-5119215558360251~5852726622';
  static const String admobAppIdIos = 'ca-app-pub-5119215558360251~6291710329';

  // Banner — LIVE
  static const String bannerAdUnitAndroid =
      'ca-app-pub-5119215558360251/4539644958';
  static const String bannerAdUnitIos =
      'ca-app-pub-5119215558360251/5231711842';

  // Interstitial — LIVE
  static const String interstitialAdUnitAndroid =
      'ca-app-pub-5119215558360251/1913481610';
  static const String interstitialAdUnitIos =
      'ca-app-pub-5119215558360251/2852259818';

  // Rewarded Interstitial — LIVE
  static const String rewardedAdUnitAndroid =
      'ca-app-pub-5119215558360251/6970801948';
  static const String rewardedAdUnitIos =
      'ca-app-pub-5119215558360251/8383255266';

  // ── Sports (MVP hardcoded — move to Firestore 'sports' collection Phase 2+) ─
  static const List<String> defaultSports = [
    'Australian Rules Football',
    'Baseball',
    'Basketball',
    'Box Lacrosse',
    'Cricket',
    'Curling',
    'Dragon Boating',
    'Field Hockey',
    'Floorball',
    'Football (US/CDA)',
    'Football/Soccer',
    'Futsal',
    'Gaelic Football',
    'Ice Hockey',
    'Lacrosse',
    'Quidditch',
    'Rugby',
    'Rugby 7s',
    'Softball',
    'Ultimate Frisbee',
    'Volleyball',
    'Water Polo',
    'Other',
  ];

  static const Map<String, List<String>> sportPositions = {
    'Ice Hockey': [
      'Goalie',
      'Left Defence',
      'Right Defence',
      'Left Wing',
      'Centre',
      'Right Wing'
    ],
    'Football/Soccer': [
      'Goalkeeper',
      'Left Back',
      'Centre Back',
      'Right Back',
      'Defensive Mid',
      'Centre Mid',
      'Left Wing',
      'Right Wing',
      'Striker'
    ],
    'Basketball': [
      'Point Guard',
      'Shooting Guard',
      'Small Forward',
      'Power Forward',
      'Centre'
    ],
    'Baseball': [
      'Pitcher',
      'Catcher',
      '1st Base',
      '2nd Base',
      '3rd Base',
      'Shortstop',
      'Left Field',
      'Centre Field',
      'Right Field',
      'DH'
    ],
    'Softball': [
      'Pitcher',
      'Catcher',
      '1st Base',
      '2nd Base',
      '3rd Base',
      'Shortstop',
      'Left Field',
      'Centre Field',
      'Right Field',
      'DH'
    ],
    // Dragon Boating: standard 10-row × 2-side + Drummer + Steersperson.
    // Row numbering is front-to-back (Row 1 = closest to drummer/front).
    // Boat balance / dynamic seat count is handled by BoatSeatingScreen (Phase 4).
    'Dragon Boating': [
      'Row 1 Left',
      'Row 1 Right',
      'Row 2 Left',
      'Row 2 Right',
      'Row 3 Left',
      'Row 3 Right',
      'Row 4 Left',
      'Row 4 Right',
      'Row 5 Left',
      'Row 5 Right',
      'Row 6 Left',
      'Row 6 Right',
      'Row 7 Left',
      'Row 7 Right',
      'Row 8 Left',
      'Row 8 Right',
      'Row 9 Left',
      'Row 9 Right',
      'Row 10 Left',
      'Row 10 Right',
      'Drummer',
      'Steersperson',
    ],
    'Volleyball': [
      'Setter',
      'Outside Hitter',
      'Middle Blocker',
      'Opposite',
      'Libero'
    ],
    'Football (US/CDA)': [
      'Quarterback',
      'Running Back',
      'Wide Receiver',
      'Tight End',
      'Offensive Line',
      'Defensive Line',
      'Linebacker',
      'Cornerback',
      'Safety'
    ],
    'Lacrosse': ['Goalie', 'Defence', 'Midfielder', 'Attack'],
    'Box Lacrosse': [
      'Goalie',
      'Centre',
      'Left Wing',
      'Right Wing',
      'Left Defence',
      'Right Defence'
    ],
    'Curling': ['Lead', 'Second', 'Vice', 'Skip'],
    'Cricket': [
      'Opener',
      'Top Order Batsman',
      'Middle Order Batsman',
      'All-Rounder',
      'Wicket-Keeper',
      'Fast Bowler',
      'Medium Pace Bowler',
      'Spin Bowler'
    ],
    'Ultimate Frisbee': [
      'Handler 1',
      'Handler 2',
      'Handler 3',
      'Cutter 1',
      'Cutter 2',
      'Cutter 3',
      'Cutter 4'
    ],
    'Australian Rules Football': [
      'Full Forward',
      'Left Forward Pocket',
      'Right Forward Pocket',
      'Left Half Forward',
      'Centre Half Forward',
      'Right Half Forward',
      'Left Wing',
      'Centre',
      'Right Wing',
      'Ruck',
      'Ruck Rover',
      'Rover',
      'Left Half Back',
      'Centre Half Back',
      'Right Half Back',
      'Left Back Pocket',
      'Full Back',
      'Right Back Pocket',
    ],
    'Water Polo': [
      'Goalkeeper',
      'Left Wing',
      'Right Wing',
      'Left Driver',
      'Right Driver',
      'Centre Forward',
      'Point'
    ],
    'Floorball': [
      'Goalkeeper',
      'Left Wing',
      'Centre',
      'Right Wing',
      'Left Defender',
      'Right Defender'
    ],
    'Gaelic Football': [
      'Goalkeeper',
      'Right Corner Back',
      'Full Back',
      'Left Corner Back',
      'Right Half Back',
      'Centre Back',
      'Left Half Back',
      'Right Midfielder',
      'Left Midfielder',
      'Right Half Forward',
      'Centre Forward',
      'Left Half Forward',
      'Right Corner Forward',
      'Full Forward',
      'Left Corner Forward',
    ],
    'Quidditch': [
      'Keeper',
      'Chaser 1',
      'Chaser 2',
      'Chaser 3',
      'Beater 1',
      'Beater 2',
      'Seeker'
    ],
    'Rugby': [
      'Loosehead Prop',
      'Hooker',
      'Tighthead Prop',
      'Left Lock',
      'Right Lock',
      'Blindside Flanker',
      'Openside Flanker',
      'Number 8',
      'Scrum-Half',
      'Fly-Half',
      'Left Wing',
      'Inside Centre',
      'Outside Centre',
      'Right Wing',
      'Fullback',
    ],
    'Rugby 7s': [
      'Prop',
      'Hooker',
      'Flanker',
      'Scrum-Half',
      'Fly-Half',
      'Centre',
      'Fullback',
    ],
    'Futsal': ['Goalkeeper', 'Fixo', 'Right Wing', 'Left Wing', 'Pivot'],
    'Field Hockey': [
      'Goalkeeper',
      'Right Defender',
      'Sweeper',
      'Left Defender',
      'Right Midfielder',
      'Centre Midfielder',
      'Left Midfielder',
      'Right Wing',
      'Centre Forward',
      'Left Wing',
      'Striker',
    ],
    'Other': [
      'Position 1',
      'Position 2',
      'Position 3',
      'Position 4',
      'Position 5'
    ],
  };

  static List<String> positionsForSport(String sport) =>
      sportPositions[sport] ?? sportPositions['Other']!;

  /// Named position categories per sport.
  /// Keys are display labels selectable as preferences.
  /// Values are the specific positions that category covers.
  static const Map<String, Map<String, List<String>>> sportPositionCategories =
      {
    'Ice Hockey': {
      'Any Forward': ['Left Wing', 'Centre', 'Right Wing'],
      'Any Wing': ['Left Wing', 'Right Wing'],
      'Any Defence': ['Left Defence', 'Right Defence'],
      'Any (except Goalie)': [
        'Left Defence',
        'Right Defence',
        'Left Wing',
        'Centre',
        'Right Wing'
      ],
    },
    'Football/Soccer': {
      'Any Defender': ['Left Back', 'Centre Back', 'Right Back'],
      'Any Midfielder': ['Defensive Mid', 'Centre Mid'],
      'Any Wing': ['Left Wing', 'Right Wing'],
      'Any Outfield': [
        'Left Back',
        'Centre Back',
        'Right Back',
        'Defensive Mid',
        'Centre Mid',
        'Left Wing',
        'Right Wing',
        'Striker'
      ],
    },
    'Basketball': {
      'Any Guard': ['Point Guard', 'Shooting Guard'],
      'Any Forward': ['Small Forward', 'Power Forward'],
      'Any (except Centre)': [
        'Point Guard',
        'Shooting Guard',
        'Small Forward',
        'Power Forward'
      ],
    },
    'Baseball': {
      'Any Infield': ['1st Base', '2nd Base', '3rd Base', 'Shortstop'],
      'Any Outfield': ['Left Field', 'Centre Field', 'Right Field'],
      'Any (except Pitcher)': [
        'Catcher',
        '1st Base',
        '2nd Base',
        '3rd Base',
        'Shortstop',
        'Left Field',
        'Centre Field',
        'Right Field',
        'DH'
      ],
    },
    'Softball': {
      'Any Infield': ['1st Base', '2nd Base', '3rd Base', 'Shortstop'],
      'Any Outfield': ['Left Field', 'Centre Field', 'Right Field'],
      'Any (except Pitcher)': [
        'Catcher',
        '1st Base',
        '2nd Base',
        '3rd Base',
        'Shortstop',
        'Left Field',
        'Centre Field',
        'Right Field',
        'DH'
      ],
    },
    'Dragon Boating': {
      'Left Side': [
        'Row 1 Left',
        'Row 2 Left',
        'Row 3 Left',
        'Row 4 Left',
        'Row 5 Left',
        'Row 6 Left',
        'Row 7 Left',
        'Row 8 Left',
        'Row 9 Left',
        'Row 10 Left'
      ],
      'Right Side': [
        'Row 1 Right',
        'Row 2 Right',
        'Row 3 Right',
        'Row 4 Right',
        'Row 5 Right',
        'Row 6 Right',
        'Row 7 Right',
        'Row 8 Right',
        'Row 9 Right',
        'Row 10 Right'
      ],
      'Front (Rows 1–3)': [
        'Row 1 Left',
        'Row 1 Right',
        'Row 2 Left',
        'Row 2 Right',
        'Row 3 Left',
        'Row 3 Right'
      ],
      'Middle (Rows 4–7)': [
        'Row 4 Left',
        'Row 4 Right',
        'Row 5 Left',
        'Row 5 Right',
        'Row 6 Left',
        'Row 6 Right',
        'Row 7 Left',
        'Row 7 Right'
      ],
      'Back (Rows 8–10)': [
        'Row 8 Left',
        'Row 8 Right',
        'Row 9 Left',
        'Row 9 Right',
        'Row 10 Left',
        'Row 10 Right'
      ],
      'Any Paddler': [
        'Row 1 Left',
        'Row 1 Right',
        'Row 2 Left',
        'Row 2 Right',
        'Row 3 Left',
        'Row 3 Right',
        'Row 4 Left',
        'Row 4 Right',
        'Row 5 Left',
        'Row 5 Right',
        'Row 6 Left',
        'Row 6 Right',
        'Row 7 Left',
        'Row 7 Right',
        'Row 8 Left',
        'Row 8 Right',
        'Row 9 Left',
        'Row 9 Right',
        'Row 10 Left',
        'Row 10 Right'
      ],
    },
    'Volleyball': {
      'Any Hitter': ['Outside Hitter', 'Middle Blocker', 'Opposite'],
    },
    'Football (US/CDA)': {
      'Any Skill': [
        'Quarterback',
        'Running Back',
        'Wide Receiver',
        'Tight End'
      ],
      'Any Offensive': [
        'Quarterback',
        'Running Back',
        'Wide Receiver',
        'Tight End',
        'Offensive Line'
      ],
      'Any Defensive': ['Defensive Line', 'Linebacker', 'Cornerback', 'Safety'],
    },
    'Lacrosse': {
      'Any Field Player': ['Defence', 'Midfielder', 'Attack'],
    },
    'Box Lacrosse': {
      'Any Forward': ['Centre', 'Left Wing', 'Right Wing'],
      'Any Defence': ['Left Defence', 'Right Defence'],
    },
    'Cricket': {
      'Any Batsman': [
        'Opener',
        'Top Order Batsman',
        'Middle Order Batsman',
        'All-Rounder',
        'Wicket-Keeper'
      ],
      'Any Bowler': [
        'Fast Bowler',
        'Medium Pace Bowler',
        'Spin Bowler',
        'All-Rounder'
      ],
    },
    'Ultimate Frisbee': {
      'Any Handler': ['Handler 1', 'Handler 2', 'Handler 3'],
      'Any Cutter': ['Cutter 1', 'Cutter 2', 'Cutter 3', 'Cutter 4'],
    },
    'Australian Rules Football': {
      'Any Forward': [
        'Full Forward',
        'Left Forward Pocket',
        'Right Forward Pocket',
        'Left Half Forward',
        'Centre Half Forward',
        'Right Half Forward'
      ],
      'Any Midfield': [
        'Left Wing',
        'Centre',
        'Right Wing',
        'Ruck',
        'Ruck Rover',
        'Rover'
      ],
      'Any Back': [
        'Left Half Back',
        'Centre Half Back',
        'Right Half Back',
        'Left Back Pocket',
        'Full Back',
        'Right Back Pocket'
      ],
    },
    'Water Polo': {
      'Any Field Player': [
        'Left Wing',
        'Right Wing',
        'Left Driver',
        'Right Driver',
        'Centre Forward',
        'Point'
      ],
    },
    'Floorball': {
      'Any Forward': ['Left Wing', 'Centre', 'Right Wing'],
      'Any Defender': ['Left Defender', 'Right Defender'],
    },
    'Gaelic Football': {
      'Any Back': [
        'Right Corner Back',
        'Full Back',
        'Left Corner Back',
        'Right Half Back',
        'Centre Back',
        'Left Half Back'
      ],
      'Any Midfield': ['Right Midfielder', 'Left Midfielder'],
      'Any Forward': [
        'Right Half Forward',
        'Centre Forward',
        'Left Half Forward',
        'Right Corner Forward',
        'Full Forward',
        'Left Corner Forward'
      ],
    },
    'Quidditch': {
      'Any Chaser': ['Chaser 1', 'Chaser 2', 'Chaser 3'],
      'Any Beater': ['Beater 1', 'Beater 2'],
    },
    'Rugby': {
      'Any Forward': [
        'Loosehead Prop',
        'Hooker',
        'Tighthead Prop',
        'Left Lock',
        'Right Lock',
        'Blindside Flanker',
        'Openside Flanker',
        'Number 8'
      ],
      'Any Prop': ['Loosehead Prop', 'Tighthead Prop'],
      'Any Lock': ['Left Lock', 'Right Lock'],
      'Any Flanker': ['Blindside Flanker', 'Openside Flanker'],
      'Any Back': [
        'Scrum-Half',
        'Fly-Half',
        'Left Wing',
        'Inside Centre',
        'Outside Centre',
        'Right Wing',
        'Fullback'
      ],
      'Any Centre': ['Inside Centre', 'Outside Centre'],
      'Any Wing': ['Left Wing', 'Right Wing'],
    },
    'Rugby 7s': {
      'Any Forward': ['Prop', 'Hooker', 'Flanker'],
      'Any Back': ['Scrum-Half', 'Fly-Half', 'Centre', 'Fullback'],
    },
    'Futsal': {
      'Any Outfield': ['Fixo', 'Right Wing', 'Left Wing', 'Pivot'],
    },
    'Field Hockey': {
      'Any Defender': ['Right Defender', 'Sweeper', 'Left Defender'],
      'Any Midfielder': [
        'Right Midfielder',
        'Centre Midfielder',
        'Left Midfielder'
      ],
      'Any Forward': ['Right Wing', 'Centre Forward', 'Left Wing', 'Striker'],
    },
  };

  /// Returns position categories for a sport, or empty map if none defined.
  static Map<String, List<String>> categoriesForSport(String sport) =>
      sportPositionCategories[sport] ?? {};

  /// Returns true if [position] is covered by [preference] for [sport].
  /// preference can be a specific position name or a category name.
  static bool positionMatchesPreference(
      String position, String preference, String sport) {
    if (preference == 'Any') return true;
    if (preference == position) return true;
    final cats = sportPositionCategories[sport]?[preference];
    return cats?.contains(position) ?? false;
  }

  // ── Google Places ─────────────────────────────────────────────────────────
  // Two separate API keys needed: one for Android, one for iOS.
  // Each key must be restricted to its platform in Google Cloud Console.
  //
  // Local build:
  //   flutter build apk --dart-define=GOOGLE_PLACES_API_KEY_ANDROID=... --dart-define=GOOGLE_PLACES_API_KEY_IOS=...
  // Codemagic: set both env vars in Keys group
  static String get googlePlacesApiKey {
    final androidKey = const String.fromEnvironment(
        'GOOGLE_PLACES_API_KEY_ANDROID',
        defaultValue: '');
    final iosKey = const String.fromEnvironment('GOOGLE_PLACES_API_KEY_IOS',
        defaultValue: '');

    // Use platform-appropriate key
    if (Platform.isIOS && iosKey.isNotEmpty) {
      return iosKey;
    }
    if (Platform.isAndroid && androidKey.isNotEmpty) {
      return androidKey;
    }

    // Fallback: prefer iOS key for testing if only one is set
    if (iosKey.isNotEmpty) return iosKey;
    if (androidKey.isNotEmpty) return androidKey;

    // Legacy single key fallback
    return const String.fromEnvironment('GOOGLE_PLACES_API_KEY',
        defaultValue: '');
  }

  // ── Feature Flags ─────────────────────────────────────────────────────────
  // Toggle incomplete Phase 2+ features without removing code
  static const bool enableAutoLineup = true; // Phase 3 — enabled
  static const bool enableRewardedAds = true;
  static const bool enablePdfExport = true; // Phase 3
}
