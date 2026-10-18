# IronLog

IronLog is a personal training log. It runs as a Vue 3 web app and as a Capacitor shell on Android and iOS. Accounts, body metrics, routines, and workout history live in Supabase. Row Level Security limits every profile, routine, workout, set, and custom exercise to the signed-in user.

The native application id is `com.akhyar.ironlog`. Version 1.0.0 is Android `versionCode` 1 and `versionName` `1.0.0`.

Related documents at the repository root:

- [`ARCHITECTURE_BLUEPRINT.md`](../ARCHITECTURE_BLUEPRINT.md) — behavior inherited from the legacy client, and the defects this rebuild closes.
- [`PRIVACY_AND_DATA_SAFETY.md`](../PRIVACY_AND_DATA_SAFETY.md) — data inventory for the in-app policy (`/privacy`) and the Google Play Data Safety form.

## Tech stack

| Layer | Choice |
| --- | --- |
| UI | Vue 3, Vue Router, Tailwind CSS 4, Lucide |
| State | Pinia |
| Language | TypeScript |
| Build | Vite 8, `vue-tsc` |
| Tests | Vitest (`src/**/*.spec.ts`) |
| Charts | Chart.js and vue-chartjs |
| Native | Capacitor 8 (Android and iOS), Capacitor Haptics |
| Backend | Supabase Auth, Postgres, Storage, and two SQL functions |

There is no application server in this repository. The client talks to Supabase over HTTPS with the publishable key.

## Key features

### Auth

Email and password sign-in, a multi-step registration form, and a 6-digit signup code when the Supabase project requires email confirmation. Password reset sends a recovery email and finishes with a 6-digit code plus a new password (at least 6 characters). Registration writes `public.profiles` after a session exists. There is no `auth.users` trigger that inserts a profile.

Edit Profile can permanently delete the account. The user types `DELETE`. The app calls `public.delete_own_account()`, which removes avatar objects and the `auth.users` row. Related rows cascade. The draft workout key `ironlog.activeWorkout.v1` is cleared and the session ends.

### Body metrics

The dashboard computes BMI, FFMI, bench-to-bodyweight, and goal progress from the profile. Units are centimetres, kilograms, and percent body fat.

- BMI bands are UNDERWEIGHT, HEALTHY, OVERWEIGHT, and OBESE.
- FFMI needs height, weight, and body fat.
- The U.S. Navy tape calculator branches on gender (case-insensitive). Female estimates require hips. The result is rounded to one decimal and clamped to 3.0–50.0, then saved to `current_body_fat`.
- Goal progress uses `min(current, target) / max(current, target)`, so a cut does not fill the bar only because current weight is already above target.
- Bench ratio uses the heaviest `category = bench` set in the latest bench workout, divided by current weight, and falls back to the all-time bench max.

Avatars are optional JPEG, PNG, or WebP images up to 5 MB, stored at `avatars/{userId}/avatar`.

### Live workout tracker

Routines are ordered exercise lists with a per-exercise rest default (180 seconds). An empty workout starts with the title `Empty Workout` and no exercises.

The live session is kept in Pinia and in `localStorage` under `ironlog.activeWorkout.v1`, so a reload does not drop the draft. Each exercise prefills from that user’s previous session and tracks weight and reps, bodyweight reps, or duration. The user can check sets, add or remove sets, add, replace, or remove exercises, and keep per-exercise notes.

One rest timer runs for the session (±15 seconds, skip, clamped to 0–999). A checked set whose weight beats the in-session max plays confetti and a heavy haptic. Finish requires at least one checked set. Save calls the `save_completed_workout` Postgres function, which inserts the workout and its sets in one transaction and derives volume, set count, `is_pr`, and `records_broken`. The client does not send those totals. Discard writes nothing.

### Analytics

- Dashboard: sets since Monday, a 30- or 90-day Monday-bucket chart of volume or set count, and recent history (last 96 days). Past logs can have their date and clock times edited. Deleting a workout cascades its sets.
- Workout detail: sets grouped by exercise, a muscle split from `primary_muscle`, personal-record flags from the database, and a top-set badge (`weight × reps`).
- Stats: the last 7 days, muscle chips, a body map for the selected day or for 30 or 90 days, and lifetime workout count, hours, volume, and sets.
- Personal records: best weight, then reps, per exercise, with an Epley estimated 1RM. Exercise detail uses Brzycki and skips sets at 37 reps or more.
- Calendar: month grid, days that have a workout, the selected day’s sessions, a Monday–Sunday week streak, and rest days since the latest session.

A shared catalog of 44 exercises is seeded by `supabase/02_seed.sql`. Users can add custom exercises. Custom rows that still appear in set history cannot be deleted.

## Local setup and prerequisites

- Node.js and npm
- A Supabase project
- Android builds: JDK 21 and an Android SDK. `android/local.properties` must set `sdk.dir`. The debug script expects JDK at `/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home` and the SDK at `$HOME/Library/Android/sdk`.
- iOS builds: Xcode and a signing team

```bash
cd ironlog-app
npm install
cp .env.example .env
```

Set these in `.env`. The file is gitignored. `.env.example` is the only env file that is committed.

| Variable | Required | Purpose |
| --- | --- | --- |
| `VITE_SUPABASE_URL` | Yes | Supabase project URL |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | Yes | Publishable or anon key. Read first |
| `VITE_SUPABASE_ANON_KEY` | Fallback | Used when the publishable key is empty |
| `VITE_ENABLE_DEMO_SEED` | No | `true` includes the Edit Profile demo seeder in a production build. `npm run dev` shows it without this flag |

```bash
npm run dev
```

The dev server is `http://127.0.0.1:5173/`.

```bash
npm test
npm run build
npm run preview
```

`npm test` runs Vitest. Specs cover fitness math, error copy, sign-in, recovery OTP, account deletion, and the live workout store. `npm run build` typechecks with `vue-tsc` and writes `dist/`.

## Supabase migration steps

Apply the SQL in the Supabase SQL editor on a new project, in this order. Paths are from the repository root, not from `ironlog-app/`.

1. `supabase/01_schema.sql`
2. `supabase/02_seed.sql`

`01_schema.sql` creates `profiles`, `exercises`, `routines`, `routine_exercises`, `workouts`, and `set_logs`, plus checks, indexes, Row Level Security, the public `avatars` bucket (5 MB, JPEG/PNG/WebP), `normalize_profile`, `save_completed_workout`, and `delete_own_account`. Authenticated users cannot insert global catalog rows. `02_seed.sql` inserts those 44 exercises and is safe to re-run (`on conflict (id) do nothing`).

Do not replay `01_schema.sql` on a database that already has these tables. On an existing project, run only the `delete_own_account` function at the end of that file if it is missing.

In the Supabase Auth settings, enable email sign-in and set the Site URL to the deployed origin so signup and recovery mail can return to the app. The client does not pass `emailRedirectTo`. Keep the service role key out of the Vite build. The client only receives the publishable key.

After the catalog seed, Edit Profile can insert six demo workouts (`Demo Push` and `Demo Pull`) when the seeder is compiled in. A second run is refused until those sessions are deleted.

## Android build

`android:allowBackup` is `false`, so a device backup cannot copy the WebView session. Release builds enable minify and resource shrinking and require a signing config.

Create a keystore once and keep it out of git:

```bash
mkdir -p android/keystore
keytool -genkeypair -v \
  -keystore android/keystore/ironlog-release.jks \
  -alias ironlog -keyalg RSA -keysize 2048 -validity 10000
cp android/keystore.properties.example android/keystore.properties
```

Put the store password, key alias, and key password in `android/keystore.properties`. That file, `android/keystore/`, `*.jks`, and `*.keystore` are gitignored. The same values can be supplied with `IRONLOG_KEYSTORE_PATH`, `IRONLOG_KEYSTORE_PASSWORD`, `IRONLOG_KEY_ALIAS`, and `IRONLOG_KEY_PASSWORD`. Environment variables win when they are set. `assembleRelease` and `bundleRelease` fail if signing is missing.

```bash
npm run apk:sync
npm run apk:open
npm run apk:build-debug
npm run apk:build-release
```

`apk:build-debug` builds the web bundle, runs `cap sync android`, and `assembleDebug`. `apk:build-release` produces a signed `app-release.apk` and an `.aab`.

## iOS build

The Xcode project is already in `ios/`. From `ironlog-app`:

```bash
npm run build
npx cap sync ios
npx cap open ios
```

Open `ios/App/App.xcworkspace`, select a signing team, and run on a simulator or device. Use `npx cap add ios` only on a machine that does not already have the `ios/` project.

## Project layout

| Path | Role |
| --- | --- |
| `src/views` | Screens. Login, registration, and `/privacy` sit outside the shell |
| `src/components/AppShell.vue` | Signed-in layout. The dock hides on `/live` and `/live/save` |
| `src/stores/authStore.ts` | Session and profile |
| `src/stores/activeWorkoutStore.ts` | Live session and `save_completed_workout` |
| `src/stores/exerciseStore.ts` | Catalog, custom exercises, Brzycki stats |
| `src/stores/routineStore.ts` | Routines and ordered exercises |
| `src/stores/historyStore.ts` | History, bench ratio, records, calendar data |
| `src/utils/fitnessMath.ts` | BMI, FFMI, Navy body fat, 1RM, volume, streaks |
| `src/lib/supabase.ts` | Supabase client. Throws if the URL or key is missing |
| `../supabase/01_schema.sql` | Schema, RLS, and functions |
| `../supabase/02_seed.sql` | Global exercise catalog |
