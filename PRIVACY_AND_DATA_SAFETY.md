# IronLog privacy and Google Play Data Safety

IronLog is a personal training log. This note is the source for the in-app privacy policy and the Google Play Data Safety form.

## Data collected

| Data | Required | Play Data Safety category |
| --- | --- | --- |
| Email address | Yes, to create an account | Personal info |
| Username, display name, bio | Username yes; name and bio optional | Personal info |
| Birth date | Collected on registration | Personal info |
| Gender | Collected on registration | Personal info |
| Height, weight, target weight | Yes, for body metrics | Health and fitness |
| Body-fat percentage | Optional | Health and fitness |
| Workout logs (exercise, sets, weight, reps, duration, notes) | Created by the user while training | Health and fitness |
| Avatar photo | Optional, only if the user uploads one | Photos |

IronLog does not collect contacts, location, financial info, or advertising identifiers. It does not sell data and does not share it with advertisers.

## Why it is collected

- Email and password authentication identify the account.
- Height, weight, and body fat feed BMI and FFMI calculations shown on the dashboard.
- Workout logs feed volume and estimated 1RM figures.
- Records are synced to the user's private Supabase project so the same history is available after reinstall or on another sign-in.

## How it is protected

- The app talks to Supabase over HTTPS, so data is encrypted in transit.
- Postgres Row Level Security restricts profiles, routines, workouts, set logs, and avatar storage paths to the signed-in user.
- Android backups are disabled (`android:allowBackup="false"`) so a device backup cannot extract the WebView session.

## Deletion

A signed-in user can permanently delete their account and all of the data above from Edit Profile:

1. Open Edit Profile.
2. Choose Delete Account.
3. Type `DELETE` and confirm.

That action calls `public.delete_own_account()`, which removes the user's avatar objects and their `auth.users` row. Related profile, routine, workout, and exercise rows cascade with that delete.

## Play console answers

- Data is collected and stored on the developer's Supabase backend.
- Data is encrypted in transit.
- Users can request deletion inside the app without contacting support.
- Data is not used for ads or shared with data brokers.
