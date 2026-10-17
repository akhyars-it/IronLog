# IronLog

IronLog is a Vue 3 training log that runs on the web and as a Capacitor Android and iOS app. Accounts, body metrics, routines, and workout history live in Supabase. The signed-in user is the only person who can read or change their rows.

## Setup

```bash
cd ironlog-app
npm install
cp .env.example .env
```

Set these in `.env` (the file is gitignored):

- `VITE_SUPABASE_URL` — project URL
- `VITE_SUPABASE_PUBLISHABLE_KEY` — publishable or anon key (`VITE_SUPABASE_ANON_KEY` is also accepted)

```bash
npm run dev
```

The dev server is `http://127.0.0.1:5173/`.

## Architecture

- `src/views` — screens. Auth and registration sit outside the shell. The signed-in app is `AppShell` plus a floating bottom dock.
- `src/stores` — Pinia. `authStore` owns the session and profile. `activeWorkoutStore` keeps the live session in `localStorage` under `ironlog.activeWorkout.v1` and saves it with the `save_completed_workout` RPC.
- `src/utils/fitnessMath.ts` — BMI, FFMI, volume, and 1RM helpers.
- `src/utils/errorHandler.ts` — turns Supabase and Postgres errors into short messages before they reach the UI.
- `src/lib/supabase.ts` — untyped Supabase client.

Registration writes the profile row after a session exists. The schema does not insert a profile from an `auth.users` trigger.

## Supabase

In the SQL editor, run the files in order on a new project:

1. `supabase/01_schema.sql`
2. `supabase/02_seed.sql`

`01_schema.sql` creates tables, Row Level Security, the avatar bucket, `save_completed_workout`, and `delete_own_account`. On a project that already has the tables, run the `delete_own_account` function at the end of `01_schema.sql` instead of replaying the whole file.

Account deletion is available in Edit Profile. The user types `DELETE`, the app calls `delete_own_account`, clears local session data, and returns to the login screen.

## Testing

```bash
npm test
```

That runs Vitest (`npx vitest run`). Coverage includes fitness math, the error sanitizer, auth sign-in, recovery OTP, account deletion, and the live workout store (volume, PR detection, rest bounds, and the save payload).

## Android

Requirements: JDK 21 and an Android SDK. `android/local.properties` should point `sdk.dir` at the SDK.

Release builds are signed. Create a keystore once and keep it out of git:

```bash
mkdir -p android/keystore
keytool -genkeypair -v \
  -keystore android/keystore/ironlog-release.jks \
  -alias ironlog -keyalg RSA -keysize 2048 -validity 10000
cp android/keystore.properties.example android/keystore.properties
```

Put the store password, key alias, and key password in `android/keystore.properties`. Both that file and `android/keystore/` are gitignored. The same values can be supplied with `IRONLOG_KEYSTORE_PATH`, `IRONLOG_KEYSTORE_PASSWORD`, `IRONLOG_KEY_ALIAS`, and `IRONLOG_KEY_PASSWORD`. Environment variables win when they are set.

```bash
npm run apk:build-debug
npm run apk:build-release
```

`apk:build-release` produces a minified, resource-shrunk, signed `app-release.apk` and an `.aab`. Version 1.0.0 is `versionCode` 1 and `versionName` `1.0.0`. Android backups are off so a device backup cannot lift the WebView session.

`npm run apk:open` opens the project in Android Studio. `npm run apk:sync` rebuilds the web bundle and copies it into the native project.

## iOS

```bash
npx cap add ios
npx cap sync
npx cap open ios
```

Open `ios/App/App.xcworkspace` in Xcode, select a signing team, and run on a simulator or device.

## Privacy

The in-app policy is at `/privacy`. The Play Data Safety notes are in `PRIVACY_AND_DATA_SAFETY.md` at the repository root.

The demo-data seeder on Edit Profile is compiled only for `npm run dev`, or when `VITE_ENABLE_DEMO_SEED=true`. Production builds omit it.
