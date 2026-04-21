import 'package:flutter_test/flutter_test.dart';
import 'package:sports_rostering/features/events/domain/event.dart';

void main() {
  final _now    = DateTime.now();
  final _past   = _now.subtract(const Duration(hours: 1));
  final _future = _now.add(const Duration(hours: 1));

  Event _make({
    EventType   type         = EventType.practice,
    DateTime?   date,
    bool        allowSignups = true,
    DateTime?   rsvpDeadline,
    bool        cancelled    = false,
  }) =>
      Event(
        eventId:     'ev1',
        teamId:      'team1',
        type:        type,
        date:        date ?? _future,
        location:    'Test Arena',
        minPlayers:  5,
        maxPlayers:  20,
        allowSignups: allowSignups,
        rsvpDeadline: rsvpDeadline,
        cancelled:   cancelled,
        createdAt:   _now,
      );

  group('Event.isUpcoming', () {
    test('true for future date', () => expect(_make(date: _future).isUpcoming, isTrue));
    test('false for past date',  () => expect(_make(date: _past).isUpcoming,   isFalse));
  });

  group('Event.rsvpOpen', () {
    test('open when allowSignups and no deadline',  () => expect(_make().rsvpOpen, isTrue));
    test('closed when allowSignups false',          () => expect(_make(allowSignups: false).rsvpOpen, isFalse));
    test('closed when past deadline',               () => expect(_make(rsvpDeadline: _past).rsvpOpen, isFalse));
    test('open when future deadline',               () => expect(_make(rsvpDeadline: _future).rsvpOpen, isTrue));
  });

  group('Event.isCancelled', () {
    test('false by default',        () => expect(_make().isCancelled, isFalse));
    test('true when flag set',      () => expect(_make(cancelled: true).isCancelled, isTrue));
  });

  group('Event.isDropIn', () {
    test('false for practice', () => expect(_make(type: EventType.practice).isDropIn, isFalse));
    test('false for game',     () => expect(_make(type: EventType.game).isDropIn,     isFalse));
    test('true for dropIn',    () => expect(_make(type: EventType.dropIn).isDropIn,   isTrue));
  });

  group('EventType labels and icons', () {
    test('game',     () { expect(EventType.game.label,     'Game');    expect(EventType.game.icon,     '🏆'); });
    test('practice', () { expect(EventType.practice.label, 'Practice'); expect(EventType.practice.icon, '🏋️'); });
    test('dropIn',   () { expect(EventType.dropIn.label,   'Drop-in'); expect(EventType.dropIn.icon,   '🔓'); });
  });

  group('GameResult', () {
    test('win', () {
      final r = GameResult(opponentName: 'Rivals', ourScore: 3, opponentScore: 1);
      expect(r.isWin, isTrue); expect(r.isLoss, isFalse); expect(r.isTie, isFalse);
      expect(r.resultLabel, 'W');
    });
    test('loss', () {
      final r = GameResult(opponentName: 'Rivals', ourScore: 1, opponentScore: 3);
      expect(r.isLoss, isTrue); expect(r.resultLabel, 'L');
    });
    test('tie', () {
      final r = GameResult(opponentName: 'Rivals', ourScore: 2, opponentScore: 2);
      expect(r.isTie, isTrue); expect(r.resultLabel, 'T');
    });
  });

  group('BoatConfig', () {
    test('rowsPerBoat = seatsPerBoat / 2', () {
      const cfg = BoatConfig(numBoats: 1, seatsPerBoat: 20, hasDrummer: true);
      expect(cfg.rowsPerBoat, equals(10));
    });
    test('defaults', () {
      expect(BoatConfig.defaults.numBoats,     equals(1));
      expect(BoatConfig.defaults.seatsPerBoat, equals(20));
      expect(BoatConfig.defaults.hasDrummer,   isTrue);
    });
  });
}
