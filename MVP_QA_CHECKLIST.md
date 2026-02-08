# Talky Alarm MVP QA Checklist

## Scope
- Platform: iOS 18+
- Build: Debug and Release
- Languages: English, Dutch, Spanish, Arabic, Persian
- Plans: Free and Pro (monthly/yearly)

## Functional Core
- Create alarm with title, time, and message.
- Edit existing alarm and verify changes persist after app restart.
- Enable and disable alarm from list.
- Delete alarm and verify pending notifications are removed.
- Free plan blocks creating a 4th alarm and shows paywall.

## Repeat Rules
- `Once`: fires one time at expected date/time.
- `Daily`: fires daily at selected time.
- `Weekdays`: fires Monday-Friday only.
- `Custom Days`: fires only selected weekdays.
- `Every X Hours` (Pro): next reminders align to selected time anchor.
- `Every X Days` (Pro): next reminders align to selected time anchor.
- Medicine alarms show `Next` subtitle in list.

## Voice and Playback
- Basic TTS preview speaks localized sentence.
- Premium voice option is blocked on Free, available on Pro.
- Recorded voice can be captured and saved.
- Recorded voice alarm playback works when notification is presented/tapped.
- Gradual volume:
  - Recorded voice starts low and ramps up.
  - TTS starts at reduced volume when gradual mode is on.

## Notification Reliability
- Notification permission prompt appears once and respects system setting.
- Foreground alarm shows banner/list/sound.
- Tapping delivered notification opens app and triggers alarm playback.
- On app active/background transitions, schedules are refreshed.
- Medicine repeats are replenished when app lifecycle changes or medicine notification is handled.

## Localization
- No missing key text in all 5 languages.
- Alarm editor strings are localized, including `Next reminders`.
- List row `Next` subtitle is localized.
- VoiceOver labels are localized and include next reminder for medicine alarms.
- Arabic and Persian UI direction and punctuation remain readable.

## Monetization
- Paywall shows two plans only: Monthly and Yearly.
- Restore purchases path works.
- Local DEBUG fallback test mode works when StoreKit products are unavailable.
- Pro unlock removes Free limitations immediately.

## Regression and Persistence
- App relaunch keeps alarms and repeat rules unchanged.
- Changing language does not corrupt saved alarms.
- Deleting recorded-voice alarm does not crash playback pipeline.
- Rapid toggle on/off of alarms does not create duplicate notifications.

## Release Gate
- Block release if any critical alarm delivery case fails.
- Block release if localization keys are missing in any supported language.
- Block release if free/pro gating is bypassable.
