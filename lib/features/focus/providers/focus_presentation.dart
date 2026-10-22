import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/state/local_value.dart';
import '../models/focus_view.dart';

// Layer 1 presentation; business clock and AppPrefs snapshot belong to layer 2.
final timingPreferencesProvider =
    NotifierProvider<LocalValue<TimingPreferences>, TimingPreferences>(
      () => LocalValue(const TimingPreferences()),
    );
final focusViewProvider =
    NotifierProvider<LocalValue<FocusViewData>, FocusViewData>(
      () => LocalValue(const FocusViewData()),
    );
final focusRecordsProvider = Provider<List<FocusRecordView>>((ref) => const []);
