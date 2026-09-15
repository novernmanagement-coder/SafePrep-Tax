import 'package:mixpanel_flutter/mixpanel_flutter.dart';

class MixpanelService {
  static final MixpanelService instance = MixpanelService._();
  MixpanelService._();

  Mixpanel? _mixpanel;

  static const String _token = 'f0e26131548137dd7fb8522bd6b88536';

  // Distinguishes this app's events in Mixpanel's event list. Every event
  // name passed to track() gets this prepended, e.g. 'trial_started'
  // becomes 'ST_trial_started'. Without it, events from every SafePrep
  // app (Manager, Alcohol, Español, Tax, etc.) sharing this Mixpanel
  // project collapse into one shared bucket per event name, filterable
  // only by remembering an app_name property filter on every report.
  //
  // Actual prefixes in use across the live apps (per app_name property,
  // not the aspirational scheme this comment used to describe):
  //   SafePrep Manager   → 'SP'
  //   SafePrep Español    → 'ES'
  //   SafePrep Refresher  → 'SR'
  //   SafePrep Alcohol    → 'SA'
  //   SafePrep Tax        → 'ST'
  static const String _appPrefix = 'ST';

  Future<void> init() async {
    try {
      _mixpanel = await Mixpanel.init(_token, trackAutomaticEvents: true);

      // Super property — attached automatically to every event (including
      // Mixpanel's own auto-tracked events like "App Session" and "First
      // App Open") without needing to pass app_name at every call site.
      // This is a belt-and-suspenders companion to the event-name prefix
      // above: the prefix fixes the event LIST, this fixes the PROPERTY,
      // so app_name is reliable even on events we didn't hand-instrument.
      _mixpanel?.registerSuperProperties({'app_name': _appPrefix});
    } catch (e) {
      // Silent fail — never crash the app over analytics. In particular,
      // mixpanel_flutter has no native implementation on desktop
      // platforms (Windows/macOS/Linux), so this throws a
      // MissingPluginException there; _mixpanel stays null and every
      // track()/identify()/reset() call below becomes a no-op.
    }
  }

  void track(String event, {Map<String, dynamic>? properties}) {
    try {
      _mixpanel?.track('${_appPrefix}_$event', properties: properties);
    } catch (e) {
      // Silent fail — never crash the app over analytics
    }
  }

  void identify(String userId) {
    try {
      _mixpanel?.identify(userId);
    } catch (e) {
      // Silent fail — never crash the app over analytics
    }
  }

  void reset() {
    try {
      _mixpanel?.reset();
    } catch (e) {
      // Silent fail — never crash the app over analytics
    }
  }
}
