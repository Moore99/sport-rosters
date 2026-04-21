import 'package:flutter_test/flutter_test.dart';
import 'package:sports_rostering/core/config/app_config.dart';

void main() {
  group('AppConfig.defaultSports', () {
    test('contains renamed American football', () {
      expect(AppConfig.defaultSports, contains('Football (American)'));
    });
    test('contains new Canadian football', () {
      expect(AppConfig.defaultSports, contains('Football (Canadian)'));
    });
    test('does NOT contain old US/CDA name', () {
      expect(AppConfig.defaultSports, isNot(contains('Football (US/CDA)')));
    });
    test('ends with Other', () {
      expect(AppConfig.defaultSports.last, equals('Other'));
    });
    test('no duplicates', () {
      expect(AppConfig.defaultSports.toSet().length, equals(AppConfig.defaultSports.length));
    });
  });

  group('AppConfig.sportIconAsset', () {
    test('known sports return correct paths', () {
      expect(AppConfig.sportIconAsset('Ice Hockey'),          contains('ice_hockey.svg'));
      expect(AppConfig.sportIconAsset('Basketball'),          contains('basketball.svg'));
      expect(AppConfig.sportIconAsset('Football (American)'), contains('american_football.svg'));
      expect(AppConfig.sportIconAsset('Football (Canadian)'), contains('american_football.svg'));
      expect(AppConfig.sportIconAsset('Dragon Boating'),      contains('dragon_boating.svg'));
    });
    test('unknown sport falls back to other.svg', () {
      expect(AppConfig.sportIconAsset('Underwater Basket Weaving'), contains('other.svg'));
    });
    test('every default sport has a non-empty icon path', () {
      for (final sport in AppConfig.defaultSports) {
        expect(AppConfig.sportIconAsset(sport), isNotEmpty, reason: '$sport missing icon');
      }
    });
  });

  group('AppConfig.positionsForSport', () {
    test('Ice Hockey has Goalie', () {
      expect(AppConfig.positionsForSport('Ice Hockey'), contains('Goalie'));
    });
    test('Football (American) has abbreviated positions', () {
      final pos = AppConfig.positionsForSport('Football (American)');
      expect(pos, contains('QB – Quarterback'));
      expect(pos, contains('NG – Nose Guard'));
      expect(pos, contains('K – Kicker'));
    });
    test('Football (Canadian) has Slotback', () {
      expect(AppConfig.positionsForSport('Football (Canadian)'), contains('SB – Slotback'));
    });
    test('Football (American) does NOT have Slotback', () {
      expect(AppConfig.positionsForSport('Football (American)'), isNot(contains('SB – Slotback')));
    });
    test('unknown sport falls back to Other positions', () {
      expect(AppConfig.positionsForSport('Made Up Sport'),
             equals(AppConfig.sportPositions['Other']));
    });
  });

  group('AppConfig.categoriesForSport', () {
    test('Ice Hockey has Any Forward', () {
      final cats = AppConfig.categoriesForSport('Ice Hockey');
      expect(cats, contains('Any Forward'));
      expect(cats['Any Forward'], containsAll(['Left Wing', 'Centre', 'Right Wing']));
    });
    test('Football (American) has expected categories', () {
      final cats = AppConfig.categoriesForSport('Football (American)');
      expect(cats, contains('Any Offensive Line'));
      expect(cats, contains('Any Linebacker'));
      expect(cats, contains('Any Special Teams'));
    });
    test('Football (Canadian) has Any Receiver', () {
      final cats = AppConfig.categoriesForSport('Football (Canadian)');
      expect(cats, contains('Any Receiver'));
      expect(cats['Any Receiver'], contains('SB – Slotback'));
    });
    test('unknown sport returns empty map', () {
      expect(AppConfig.categoriesForSport('Made Up Sport'), isEmpty);
    });
  });

  group('AppConfig.positionMatchesPreference', () {
    test('Any matches any position', () {
      expect(AppConfig.positionMatchesPreference('Goalie', 'Any', 'Ice Hockey'), isTrue);
      expect(AppConfig.positionMatchesPreference('Left Wing', 'Any', 'Ice Hockey'), isTrue);
    });
    test('exact position match', () {
      expect(AppConfig.positionMatchesPreference('Goalie', 'Goalie', 'Ice Hockey'), isTrue);
    });
    test('category match', () {
      expect(AppConfig.positionMatchesPreference('Left Wing', 'Any Forward', 'Ice Hockey'), isTrue);
      expect(AppConfig.positionMatchesPreference('Centre',    'Any Forward', 'Ice Hockey'), isTrue);
    });
    test('no match', () {
      expect(AppConfig.positionMatchesPreference('Goalie', 'Any Forward', 'Ice Hockey'), isFalse);
    });
    test('position in different sport does not cross-match', () {
      // 'Any Forward' in Ice Hockey shouldn't match a Basketball position
      expect(AppConfig.positionMatchesPreference('Point Guard', 'Any Forward', 'Basketball'), isFalse);
    });
  });
}
