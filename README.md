# Nightly

A small iOS app for the last two minutes of the day: three taps to say whether
today went okay, and a line of note if you feel like it.

The whole design goal is *low inhibition* — closer to brushing your teeth than
to journaling. It should be usable when you're tired, in a bad mood, or already
in bed with the lights off.

## How it works

Open the app and you're on tonight's card. Nothing else — no tabs, no dashboard,
no "welcome back".

**Three questions, on by default:**

- Happy with what you got done?
- Happy with how you ate?
- Getting to bed at a decent hour?

Each takes one tap: *Not really* / *Kind of* / *Yeah*. Tapping the same answer
again clears it. Below them is an optional note field, and one big **Log tonight**
button.

Four more questions ship switched off (movement, contact with people, kindness to
yourself, screen time), and you can add your own. Fewer is better — three questions
takes about ten seconds, which is the point.

## The details that keep it frictionless

- **Answers save on tap.** There's no submit step to forget. Quitting halfway
  through loses nothing; the Done button just marks the night as logged.
- **Logging nothing still counts.** Tap Done with every question skipped and the
  night is on record. Showing up is the habit, not the answers.
- **After midnight counts as yesterday.** Checking in at 1am is the end of the
  night before, not a skipped day plus a new one. The day rolls over at 4am.
- **The streak runs from yesterday** when today isn't in yet, so the number never
  reads `0` all day as a guilt trip.
- **Nothing scolds you.** Answers are weather (rain / part sun / sun), never faces
  or thumbs. Rough days are blue, not red. The summary line for a bad day is
  "Rough day — you still showed up."
- **One optional notification** at a time you choose. It never mentions your streak
  and never follows up.
- **Dark by default**, big tap targets, haptics on every answer.

## History

A calendar sheet shows the last five weeks as a colored grid, your streak, a
30-day "patterns" read on each question (how often it's been a good one), and
every note you've written. Tap any past day to edit it.

## Your data

Two JSON files in the app's Application Support directory. No account, no sync,
no network calls — it works in airplane mode. Settings has an **Export entries as
JSON** button, and everything is deletable from there.

## Building it

Requires Xcode 16 or newer (the project uses a file-system synchronized group, so
new files in `Nightly/Nightly/` are picked up without touching the project file).

```
open Nightly/Nightly.xcodeproj
```

Then pick a simulator or your device and hit Run. To run on your own iPhone,
change **Signing & Capabilities → Team** to your Apple ID and set a unique bundle
identifier (it ships as `com.example.Nightly`).

Deployment target is iOS 17.0.

## Layout

```
Nightly/Nightly/
  NightlyApp.swift        app entry
  Models/                 Rating, Prompt, DayEntry, DayKey, AppSettings
  Store/                  EntryStore (JSON persistence), Reminders
  Views/                  RootView, CheckInView, PromptCard, HistoryView, SettingsView
  Support/                haptics, date formatting, card styling
```

## Possible next steps

- A Lock Screen / Home Screen widget that logs a night in one tap, without opening
  the app.
- A Shortcuts action so "Hey Siri, log tonight" works from bed.
- iCloud sync, if this ever needs to live on more than one device.
- An app icon — the asset slot is there and empty.
