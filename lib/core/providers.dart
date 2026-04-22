// Central provider exports — use this instead of importing individual providers.
//
// Before: import '../../../../features/auth/presentation/providers/auth_provider.dart';
// After:  import 'package:sports_rostering/core/providers.dart';
//
// This reduces import boilerplate across ~20 screen files.
// When adding a new provider, export it here.
library;

export '../core/theme/theme_provider.dart';
export '../core/services/weight_unit_provider.dart';
export '../features/auth/presentation/providers/auth_provider.dart';
export '../features/teams/presentation/providers/teams_provider.dart';
export '../features/teams/presentation/providers/spares_provider.dart';
export '../features/teams/presentation/providers/announcements_provider.dart';
export '../features/events/presentation/providers/events_provider.dart';
export '../features/lineups/presentation/providers/lineup_provider.dart';
export '../features/lineups/presentation/providers/player_preference_provider.dart';
export '../features/rankings/presentation/providers/rankings_provider.dart';
export '../features/dropins/presentation/providers/dropin_provider.dart';
export '../features/shared/providers/ads_provider.dart';
export '../features/sports/presentation/providers/sports_provider.dart';