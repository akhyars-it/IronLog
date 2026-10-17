-- IronLog schema
-- Run this file first, on a Supabase project, before supabase/02_seed.sql.
--
-- Reconstructs the legacy tables and closes the schema gaps from the
-- architecture blueprint:
--   * gender is stored lowercase so the Navy body-fat branch can match it
--   * exercises.category is the only strength tag (no strength_category)
--   * workouts.routine_id is a real foreign key; routine_name is a snapshot
--   * records_broken defaults to 0 and is derived by save_completed_workout
--   * per-exercise notes and duration sets have columns
--   * routine order is unique and indexed; rest defaults to 180 seconds
--   * child rows cascade, except set history which blocks exercise deletion
--   * workout + sets are inserted in one transaction
--   * avatars live at {user_id}/avatar rather than {user_id}.{ext} at the bucket root
--
-- There is no auth.users trigger that inserts profiles. Registration inserts
-- the profile row itself. A second insert from a trigger would collide on id.
-- photo_url is omitted; the legacy client read it and never wrote it.

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  username text not null,
  full_name text,
  gender text not null,
  birth_date date,
  height float8,
  current_weight float8,
  target_weight float8,
  current_body_fat float8,
  bio text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_lowercase check (username = lower(username)),
  constraint profiles_username_trimmed check (username = btrim(username)),
  constraint profiles_username_present check (char_length(username) > 0),
  constraint profiles_username_unique unique (username),
  constraint profiles_gender_check check (gender in ('male', 'female', 'other')),
  constraint profiles_birth_date_not_future check (
    birth_date is null or birth_date <= current_date
  ),
  constraint profiles_height_positive check (height is null or height > 0),
  constraint profiles_current_weight_positive check (
    current_weight is null or current_weight > 0
  ),
  constraint profiles_target_weight_positive check (
    target_weight is null or target_weight > 0
  ),
  constraint profiles_body_fat_range check (
    current_body_fat is null
    or (current_body_fat >= 0 and current_body_fat <= 100)
  )
);

comment on table public.profiles is
  'One row per auth user. gender is always male, female, or other in lowercase.';

comment on column public.profiles.gender is
  'Lowercase on write. The Navy formula branches on male vs female.';

-- ---------------------------------------------------------------------------
-- Exercises
-- ---------------------------------------------------------------------------

create table public.exercises (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete cascade,
  name text not null,
  equipment text not null,
  primary_muscle text not null,
  category text not null,
  exercise_type text not null default 'reps_and_weight',
  image_url text,
  is_custom boolean not null default false,
  created_at timestamptz not null default now(),
  constraint exercises_name_present check (char_length(btrim(name)) > 0),
  constraint exercises_equipment_check check (
    equipment in (
      'Dumbbell',
      'Barbell',
      'Machine',
      'Cable',
      'Bodyweight',
      'Kettlebell'
    )
  ),
  constraint exercises_primary_muscle_check check (
    primary_muscle in (
      'Chest',
      'Back',
      'Shoulders',
      'Legs',
      'Arms',
      'Core',
      'Cardio'
    )
  ),
  constraint exercises_category_check check (
    category in (
      'bench',
      'squat',
      'deadlift',
      'overhead_press',
      'row',
      'pull',
      'push',
      'other'
    )
  ),
  constraint exercises_type_check check (
    exercise_type in ('reps_and_weight', 'bodyweight_reps', 'duration')
  ),
  -- Global catalog rows have no owner. Custom rows always have one.
  constraint exercises_owner_matches_custom check (
    (is_custom = false and user_id is null)
    or (is_custom = true and user_id is not null)
  )
);

comment on column public.exercises.category is
  'Strength tag used by the bench-to-bodyweight ratio. Replaces strength_category.';

create unique index exercises_global_name_key
  on public.exercises (lower(name))
  where is_custom = false;

create index exercises_user_id_idx
  on public.exercises (user_id)
  where user_id is not null;

create index exercises_category_idx
  on public.exercises (category);

-- ---------------------------------------------------------------------------
-- Routines
-- ---------------------------------------------------------------------------

create table public.routines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  description text,
  created_at timestamptz not null default now(),
  constraint routines_title_present check (char_length(btrim(title)) > 0)
);

create index routines_user_id_idx
  on public.routines (user_id);

create table public.routine_exercises (
  id uuid primary key default gen_random_uuid(),
  routine_id uuid not null references public.routines (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id) on delete cascade,
  order_index integer not null,
  rest_seconds integer not null default 180,
  constraint routine_exercises_order_nonnegative check (order_index >= 0),
  constraint routine_exercises_rest_nonnegative check (rest_seconds >= 0)
);

-- Unique order makes the list query deterministic. This is the
-- (routine_id, order_index) index.
create unique index routine_exercises_routine_order_idx
  on public.routine_exercises (routine_id, order_index);

create index routine_exercises_exercise_id_idx
  on public.routine_exercises (exercise_id);

-- ---------------------------------------------------------------------------
-- Workouts and sets
-- ---------------------------------------------------------------------------

create table public.workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  routine_id uuid references public.routines (id) on delete set null,
  routine_name text not null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  duration_seconds integer not null,
  total_volume float8 not null default 0,
  total_sets integer not null default 0,
  records_broken integer not null default 0,
  notes text,
  status text not null default 'completed',
  created_at timestamptz not null default now(),
  constraint workouts_routine_name_present check (char_length(btrim(routine_name)) > 0),
  constraint workouts_time_order check (end_time >= start_time),
  constraint workouts_duration_nonnegative check (duration_seconds >= 0),
  constraint workouts_volume_nonnegative check (total_volume >= 0),
  constraint workouts_sets_nonnegative check (total_sets >= 0),
  constraint workouts_records_nonnegative check (records_broken >= 0),
  constraint workouts_status_check check (status in ('completed'))
);

comment on column public.workouts.routine_id is
  'Template this session started from. Null for an empty workout. Set null if that routine is later deleted. routine_name keeps the title from save time.';

comment on column public.workouts.records_broken is
  'Count of sets flagged is_pr for this workout. Default 0. Never a display fallback.';

create index workouts_user_start_time_idx
  on public.workouts (user_id, start_time desc);

create index workouts_routine_id_idx
  on public.workouts (routine_id)
  where routine_id is not null;

create table public.set_logs (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references public.workouts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id) on delete restrict,
  set_index integer not null,
  weight float8 not null default 0,
  reps integer not null default 0,
  duration_seconds integer,
  exercise_notes text,
  is_pr boolean not null default false,
  created_at timestamptz not null default now(),
  constraint set_logs_index_positive check (set_index >= 1),
  constraint set_logs_weight_nonnegative check (weight >= 0),
  constraint set_logs_reps_nonnegative check (reps >= 0),
  constraint set_logs_duration_nonnegative check (
    duration_seconds is null or duration_seconds >= 0
  )
);

comment on column public.set_logs.exercise_notes is
  'Note captured for the exercise while logging. Copied onto each of its sets. The legacy client dropped these on save.';

comment on column public.set_logs.duration_seconds is
  'Set length for exercise_type = duration. Null for weight and rep sets.';

comment on column public.set_logs.is_pr is
  'True when this set is the session best for its exercise and beats the user''s previous best weight, or ties that weight with more reps.';

create index set_logs_user_exercise_created_idx
  on public.set_logs (user_id, exercise_id, created_at desc);

create index set_logs_workout_set_index_idx
  on public.set_logs (workout_id, set_index);

create unique index set_logs_workout_exercise_set_idx
  on public.set_logs (workout_id, exercise_id, set_index);

create index set_logs_exercise_id_idx
  on public.set_logs (exercise_id);

-- ---------------------------------------------------------------------------
-- Profile normalization
-- ---------------------------------------------------------------------------

create or replace function public.normalize_profile()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.email is not null then
    new.email := lower(btrim(new.email));
  end if;

  if new.username is not null then
    new.username := lower(btrim(new.username));
  end if;

  if new.gender is not null then
    new.gender := lower(btrim(new.gender));
  end if;

  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_normalize
  before insert or update on public.profiles
  for each row
  execute function public.normalize_profile();

-- Deleting a user cascades to exercises, but set_logs restrict that cascade
-- while history still points at those exercises. Remove the logs first.
create or replace function public.delete_set_logs_before_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.set_logs where user_id = old.id;
  return old;
end;
$$;

create trigger on_auth_user_deleted
  before delete on auth.users
  for each row
  execute function public.delete_set_logs_before_user();

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.exercises enable row level security;
alter table public.routines enable row level security;
alter table public.routine_exercises enable row level security;
alter table public.workouts enable row level security;
alter table public.set_logs enable row level security;

revoke all on table public.profiles from anon, public;
revoke all on table public.exercises from anon, public;
revoke all on table public.routines from anon, public;
revoke all on table public.routine_exercises from anon, public;
revoke all on table public.set_logs from anon, public;
revoke all on table public.workouts from anon, public;

grant select, insert, update, delete on table public.profiles to authenticated, service_role;
grant select, insert, update, delete on table public.exercises to authenticated, service_role;
grant select, insert, update, delete on table public.routines to authenticated, service_role;
grant select, insert, update, delete on table public.routine_exercises to authenticated, service_role;
grant select, insert, update, delete on table public.workouts to authenticated, service_role;
grant select, insert, update, delete on table public.set_logs to authenticated, service_role;

create policy profiles_select_own
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid());

create policy profiles_insert_own
  on public.profiles
  for insert
  to authenticated
  with check (id = auth.uid());

create policy profiles_update_own
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy profiles_delete_own
  on public.profiles
  for delete
  to authenticated
  using (id = auth.uid());

-- Any signed-in user can read the shared catalog. Custom rows stay private.
create policy exercises_select_visible
  on public.exercises
  for select
  to authenticated
  using (is_custom = false or user_id = auth.uid());

create policy exercises_insert_own
  on public.exercises
  for insert
  to authenticated
  with check (is_custom = true and user_id = auth.uid());

create policy exercises_update_own
  on public.exercises
  for update
  to authenticated
  using (is_custom = true and user_id = auth.uid())
  with check (is_custom = true and user_id = auth.uid());

create policy exercises_delete_own
  on public.exercises
  for delete
  to authenticated
  using (is_custom = true and user_id = auth.uid());

create policy routines_select_own
  on public.routines
  for select
  to authenticated
  using (user_id = auth.uid());

create policy routines_insert_own
  on public.routines
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy routines_update_own
  on public.routines
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy routines_delete_own
  on public.routines
  for delete
  to authenticated
  using (user_id = auth.uid());

create policy routine_exercises_select_own
  on public.routine_exercises
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.routines r
      where r.id = routine_id
        and r.user_id = auth.uid()
    )
  );

create policy routine_exercises_insert_own
  on public.routine_exercises
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.routines r
      where r.id = routine_id
        and r.user_id = auth.uid()
    )
    and exists (
      select 1
      from public.exercises e
      where e.id = exercise_id
        and (e.is_custom = false or e.user_id = auth.uid())
    )
  );

create policy routine_exercises_update_own
  on public.routine_exercises
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.routines r
      where r.id = routine_id
        and r.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.routines r
      where r.id = routine_id
        and r.user_id = auth.uid()
    )
    and exists (
      select 1
      from public.exercises e
      where e.id = exercise_id
        and (e.is_custom = false or e.user_id = auth.uid())
    )
  );

create policy routine_exercises_delete_own
  on public.routine_exercises
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.routines r
      where r.id = routine_id
        and r.user_id = auth.uid()
    )
  );

create policy workouts_select_own
  on public.workouts
  for select
  to authenticated
  using (user_id = auth.uid());

create policy workouts_insert_own
  on public.workouts
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and (
      routine_id is null
      or exists (
        select 1
        from public.routines r
        where r.id = routine_id
          and r.user_id = auth.uid()
      )
    )
  );

create policy workouts_update_own
  on public.workouts
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and (
      routine_id is null
      or exists (
        select 1
        from public.routines r
        where r.id = routine_id
          and r.user_id = auth.uid()
      )
    )
  );

create policy workouts_delete_own
  on public.workouts
  for delete
  to authenticated
  using (user_id = auth.uid());

create policy set_logs_select_own
  on public.set_logs
  for select
  to authenticated
  using (user_id = auth.uid());

create policy set_logs_insert_own
  on public.set_logs
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.workouts w
      where w.id = workout_id
        and w.user_id = auth.uid()
    )
    and exists (
      select 1
      from public.exercises e
      where e.id = exercise_id
        and (e.is_custom = false or e.user_id = auth.uid())
    )
  );

create policy set_logs_update_own
  on public.set_logs
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.workouts w
      where w.id = workout_id
        and w.user_id = auth.uid()
    )
    and exists (
      select 1
      from public.exercises e
      where e.id = exercise_id
        and (e.is_custom = false or e.user_id = auth.uid())
    )
  );

create policy set_logs_delete_own
  on public.set_logs
  for delete
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Avatars
-- Object key: {user_id}/avatar or {user_id}/avatar.{ext}
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.is_own_avatar_path(object_name text)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select
    object_name is not null
    and split_part(object_name, '/', 1) = auth.uid()::text
    and split_part(object_name, '/', 3) = ''
    and (
      split_part(object_name, '/', 2) = 'avatar'
      or split_part(object_name, '/', 2) ~ '^avatar\.[A-Za-z0-9]+$'
    );
$$;

revoke all on function public.is_own_avatar_path(text) from public, anon;
grant execute on function public.is_own_avatar_path(text) to authenticated, service_role;

create policy avatars_public_read
  on storage.objects
  for select
  to public
  using (
    bucket_id = 'avatars'
    and split_part(name, '/', 2) ~ '^avatar(\.[A-Za-z0-9]+)?$'
    and split_part(name, '/', 3) = ''
  );

create policy avatars_insert_own
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and public.is_own_avatar_path(name)
  );

create policy avatars_update_own
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and public.is_own_avatar_path(name)
  )
  with check (
    bucket_id = 'avatars'
    and public.is_own_avatar_path(name)
  );

create policy avatars_delete_own
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and public.is_own_avatar_path(name)
  );

-- ---------------------------------------------------------------------------
-- Atomic workout save
-- ---------------------------------------------------------------------------
-- One call inserts the workout and every completed set, then derives
-- total_sets, total_volume, is_pr, and records_broken. The caller does not
-- supply those totals, so they cannot drift from the set rows.
--
-- p_sets is a JSON array of objects:
--   exercise_id       uuid
--   set_index         int      1-based, unique per exercise in this payload
--   weight            float8   kilograms, default 0
--   reps              int      default 0
--   duration_seconds  int      optional, for duration exercises
--   exercise_notes    text     optional, stored on that set
--
-- is_pr is not taken from the client. For each exercise, the best set in the
-- payload (highest weight, then highest reps, then lowest set_index) is a PR
-- when it beats that user's previous best weight, or ties the weight with
-- more reps. A 0 x 0 duration set is not a load PR.
--
-- Returns the new workouts.id. Runs as the caller, so RLS still applies.
-- user_id is always auth.uid().

create or replace function public.save_completed_workout(
  p_routine_id uuid,
  p_routine_name text,
  p_start_time timestamptz,
  p_end_time timestamptz,
  p_duration_seconds integer,
  p_notes text,
  p_sets jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_workout_id uuid;
  v_routine_name text := btrim(coalesce(p_routine_name, ''));
  v_notes text := nullif(btrim(coalesce(p_notes, '')), '');
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_routine_name = '' then
    raise exception 'routine_name is required';
  end if;

  if p_start_time is null or p_end_time is null then
    raise exception 'start_time and end_time are required';
  end if;

  if p_end_time < p_start_time then
    raise exception 'end_time must be on or after start_time';
  end if;

  if p_duration_seconds is null or p_duration_seconds < 0 then
    raise exception 'duration_seconds must be zero or greater';
  end if;

  if p_sets is null or jsonb_typeof(p_sets) <> 'array' or jsonb_array_length(p_sets) < 1 then
    raise exception 'At least one completed set is required';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_sets) as elem
    where jsonb_typeof(elem) <> 'object'
  ) then
    raise exception 'Each completed set must be a JSON object';
  end if;

  if p_routine_id is not null and not exists (
    select 1
    from public.routines r
    where r.id = p_routine_id
      and r.user_id = v_user_id
  ) then
    raise exception 'Routine not found';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_sets) as s(
      exercise_id uuid,
      set_index integer,
      weight float8,
      reps integer,
      duration_seconds integer
    )
    where s.exercise_id is null
       or s.set_index is null
       or s.set_index < 1
       or coalesce(s.weight, 0) < 0
       or coalesce(s.reps, 0) < 0
       or (s.duration_seconds is not null and s.duration_seconds < 0)
  ) then
    raise exception 'Each set needs an exercise_id, a set_index >= 1, and non-negative weight, reps, and duration';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_sets) as s(exercise_id uuid, set_index integer)
    group by s.exercise_id, s.set_index
    having count(*) > 1
  ) then
    raise exception 'Duplicate set_index for an exercise in this workout';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_sets) as s(exercise_id uuid)
    where not exists (
      select 1
      from public.exercises e
      where e.id = s.exercise_id
        and (
          (e.is_custom = false and e.user_id is null)
          or (e.is_custom = true and e.user_id = v_user_id)
        )
    )
  ) then
    raise exception 'One or more exercises are not available to this user';
  end if;

  insert into public.workouts (
    user_id,
    routine_id,
    routine_name,
    start_time,
    end_time,
    duration_seconds,
    total_volume,
    total_sets,
    records_broken,
    notes,
    status
  )
  values (
    v_user_id,
    p_routine_id,
    v_routine_name,
    p_start_time,
    p_end_time,
    p_duration_seconds,
    0,
    0,
    0,
    v_notes,
    'completed'
  )
  returning id into v_workout_id;

  insert into public.set_logs (
    workout_id,
    user_id,
    exercise_id,
    set_index,
    weight,
    reps,
    duration_seconds,
    exercise_notes,
    is_pr
  )
  select
    v_workout_id,
    v_user_id,
    s.exercise_id,
    s.set_index,
    coalesce(s.weight, 0),
    coalesce(s.reps, 0),
    s.duration_seconds,
    nullif(btrim(s.exercise_notes), ''),
    false
  from jsonb_to_recordset(p_sets) as s(
    exercise_id uuid,
    set_index integer,
    weight float8,
    reps integer,
    duration_seconds integer,
    exercise_notes text
  );

  with best_new as (
    select distinct on (exercise_id)
      id,
      exercise_id,
      weight,
      reps
    from public.set_logs
    where workout_id = v_workout_id
    order by exercise_id, weight desc, reps desc, set_index asc
  ),
  best_old as (
    select distinct on (sl.exercise_id)
      sl.exercise_id,
      sl.weight,
      sl.reps
    from public.set_logs sl
    inner join best_new bn on bn.exercise_id = sl.exercise_id
    where sl.user_id = v_user_id
      and sl.workout_id <> v_workout_id
    order by sl.exercise_id, sl.weight desc, sl.reps desc, sl.created_at desc
  ),
  winners as (
    select bn.id
    from best_new bn
    left join best_old bo on bo.exercise_id = bn.exercise_id
    where (bn.weight > 0 or bn.reps > 0)
      and (
        bo.exercise_id is null
        or bn.weight::numeric > bo.weight::numeric
        or (
          bn.weight::numeric = bo.weight::numeric
          and bn.reps > bo.reps
        )
      )
  )
  update public.set_logs sl
  set is_pr = true
  from winners w
  where sl.id = w.id;

  update public.workouts w
  set
    total_sets = sub.total_sets,
    total_volume = sub.total_volume,
    records_broken = sub.records_broken
  from (
    select
      count(*)::integer as total_sets,
      coalesce(sum(weight * reps), 0)::float8 as total_volume,
      count(*) filter (where is_pr)::integer as records_broken
    from public.set_logs
    where workout_id = v_workout_id
  ) sub
  where w.id = v_workout_id
    and w.user_id = v_user_id;

  return v_workout_id;
end;
$$;

comment on function public.save_completed_workout(uuid, text, timestamptz, timestamptz, integer, text, jsonb) is
  'Inserts one completed workout and its sets in a single transaction, then derives volume, set count, PR flags, and records_broken.';

revoke all on function public.save_completed_workout(uuid, text, timestamptz, timestamptz, integer, text, jsonb) from public, anon;
grant execute on function public.save_completed_workout(uuid, text, timestamptz, timestamptz, integer, text, jsonb) to authenticated, service_role;

-- Profile writes run as the signed-in user, and that user must be allowed to
-- execute the before-trigger that lowercases gender and username.
revoke all on function public.normalize_profile() from public, anon;
grant execute on function public.normalize_profile() to authenticated, service_role;

-- Account deletion runs as supabase_auth_admin, not as the signed-in user.
revoke all on function public.delete_set_logs_before_user() from public, anon;
grant execute on function public.delete_set_logs_before_user() to service_role;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then
    grant execute on function public.delete_set_logs_before_user() to supabase_auth_admin;
  end if;
end;
$$;

-- Permanently deletes the signed-in account. Avatar objects are removed here
-- because storage files do not cascade from auth.users. Deleting the auth user
-- fires on_auth_user_deleted, which clears set_logs before profiles, routines,
-- workouts, and custom exercises cascade.
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public, storage, auth
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;

  delete from storage.objects
  where bucket_id = 'avatars'
    and (
      name = v_user_id::text || '/avatar'
      or name like v_user_id::text || '/%'
    );

  delete from auth.users
  where id = v_user_id;
end;
$$;

comment on function public.delete_own_account() is
  'Deletes the caller''s avatar files and auth user. Related rows cascade, and set_logs are removed by on_auth_user_deleted.';

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated, service_role;
