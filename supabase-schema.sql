-- ============================================================
--  BELAJARINGGRIS — SUPABASE DATABASE SCHEMA
--  English Centre only — no payments, no IELTS tables
--
--  HOW TO USE:
--  1. Go to Supabase → SQL Editor → New Query
--  2. Paste this entire file into the box
--  3. Click Run
--  4. Expected result: "Success. No rows returned."
-- ============================================================

-- ── 1. USER PROGRESS ────────────────────────────────────────
-- Stores every student's learning journey

create table if not exists public.user_progress (
  id                  uuid default gen_random_uuid() primary key,
  user_id             uuid references auth.users(id) on delete cascade not null,
  xp                  integer default 0,
  streak              integer default 0,
  current_week        integer default 1,
  current_level       text default 'A1',
  completed_weeks     jsonb default '[]',
  lessons_completed   integer default 0,
  quizzes_correct     integer default 0,
  quizzes_total       integer default 0,
  skill_scores        jsonb default '{
    "grammar":   0,
    "vocab":     0,
    "reading":   0,
    "writing":   0,
    "listening": 0,
    "speaking":  0
  }',
  created_at          timestamptz default now(),
  updated_at          timestamptz default now(),
  unique(user_id)
);

-- ── 2. FEEDBACK HISTORY ─────────────────────────────────────
-- Stores writing and speaking feedback for each student

create table if not exists public.feedback_history (
  id          uuid default gen_random_uuid() primary key,
  user_id     uuid references auth.users(id) on delete cascade not null,
  type        text not null,       -- 'writing' or 'speaking'
  score       numeric(4,2),        -- e.g. 7.0
  feedback    text,
  word_count  integer,
  created_at  timestamptz default now()
);

-- ── 3. ROW LEVEL SECURITY ────────────────────────────────────
-- Students can only read and write their OWN data

alter table public.user_progress    enable row level security;
alter table public.feedback_history enable row level security;

-- user_progress
create policy "users_select_own_progress"
  on public.user_progress for select
  using (auth.uid() = user_id);

create policy "users_insert_own_progress"
  on public.user_progress for insert
  with check (auth.uid() = user_id);

create policy "users_update_own_progress"
  on public.user_progress for update
  using (auth.uid() = user_id);

-- feedback_history
create policy "users_select_own_feedback"
  on public.feedback_history for select
  using (auth.uid() = user_id);

create policy "users_insert_own_feedback"
  on public.feedback_history for insert
  with check (auth.uid() = user_id);

-- ── 4. INDEXES ───────────────────────────────────────────────

create index if not exists idx_user_progress_user_id
  on public.user_progress(user_id);

create index if not exists idx_feedback_history_user_id
  on public.feedback_history(user_id);

create index if not exists idx_feedback_history_created
  on public.feedback_history(created_at desc);

-- ── 5. AUTO-UPDATE TIMESTAMPS ────────────────────────────────

create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_user_progress_updated_at
  before update on public.user_progress
  for each row execute function update_updated_at();

-- ── 6. ADMIN VIEW ────────────────────────────────────────────
-- Useful for seeing all students in the Supabase dashboard
-- Only accessible via the service role (you), not students

create or replace view public.admin_students as
select
  u.email,
  p.current_level,
  p.current_week,
  p.xp,
  p.streak,
  p.lessons_completed,
  p.quizzes_total,
  case when p.quizzes_total > 0
    then round((p.quizzes_correct::numeric / p.quizzes_total) * 100)
    else 0
  end as accuracy_pct,
  p.created_at  as joined_at,
  p.updated_at  as last_active
from public.user_progress p
join auth.users u on u.id = p.user_id
order by p.updated_at desc;

-- ── DONE ─────────────────────────────────────────────────────
-- You should see: "Success. No rows returned."
-- Verify in Supabase → Table Editor:
--   ✓ user_progress
--   ✓ feedback_history
