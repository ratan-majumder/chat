-- RTN Chat real Supabase setup
-- Run this file in Supabase Dashboard -> SQL Editor -> New Query -> Run

create extension if not exists pgcrypto;

-- Profiles connected with Supabase Auth users
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text default 'RTN User',
  username text unique,
  avatar_url text,
  cover_url text,
  bio text default '',
  note text default '',
  city text default '',
  is_verified boolean default false,
  is_admin boolean default false,
  is_banned boolean default false,
  is_private boolean default false,
  last_seen timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  from_id uuid references public.profiles(id) on delete cascade,
  to_id uuid references public.profiles(id) on delete cascade,
  status text default 'pending' check (status in ('pending','accepted','rejected','cancelled')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(from_id, to_id)
);

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_a uuid references public.profiles(id) on delete cascade,
  user_b uuid references public.profiles(id) on delete cascade,
  created_at timestamptz default now(),
  unique(user_a, user_b),
  check (user_a <> user_b)
);

create table if not exists public.blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid references public.profiles(id) on delete cascade,
  blocked_id uuid references public.profiles(id) on delete cascade,
  created_at timestamptz default now(),
  unique(blocker_id, blocked_id)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  type text not null,
  title text not null,
  body text default '',
  data jsonb default '{}'::jsonb,
  is_read boolean default false,
  created_at timestamptz default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid references public.profiles(id) on delete cascade,
  receiver_id uuid references public.profiles(id) on delete cascade,
  content text default '',
  file_url text,
  file_name text,
  file_type text,
  status text default 'sent' check (status in ('sent','delivered','read')),
  edited_at timestamptz,
  deleted_by_sender boolean default false,
  deleted_by_receiver boolean default false,
  created_at timestamptz default now()
);

create index if not exists idx_messages_pair_created on public.messages(sender_id, receiver_id, created_at);
create index if not exists idx_messages_receiver_status on public.messages(receiver_id, status);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  content text default '',
  image_url text,
  privacy text default 'public' check (privacy in ('public','friends','only_me')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.post_likes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references public.posts(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  reaction text default 'like',
  created_at timestamptz default now(),
  unique(post_id, user_id)
);

create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references public.posts(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz default now()
);

create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  text_content text default '',
  media_url text,
  media_type text,
  expires_at timestamptz default (now() + interval '24 hours'),
  created_at timestamptz default now()
);

create table if not exists public.story_views (
  id uuid primary key default gen_random_uuid(),
  story_id uuid references public.stories(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  reaction text,
  created_at timestamptz default now(),
  unique(story_id, user_id)
);

create table if not exists public.badge_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  reason text default '',
  status text default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete cascade,
  target_type text not null,
  target_id uuid,
  reason text default '',
  status text default 'pending' check (status in ('pending','resolved','rejected')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete cascade,
  name text not null,
  avatar_url text,
  created_at timestamptz default now()
);

create table if not exists public.group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid references public.groups(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  role text default 'member' check (role in ('owner','admin','member')),
  created_at timestamptz default now(),
  unique(group_id, user_id)
);

create table if not exists public.group_messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid references public.groups(id) on delete cascade,
  sender_id uuid references public.profiles(id) on delete cascade,
  content text default '',
  file_url text,
  file_name text,
  file_type text,
  created_at timestamptz default now()
);

create table if not exists public.app_settings (
  id int primary key default 1,
  app_name text default 'RTN Chat',
  primary_color text default '#1877f2',
  logo_url text,
  maintenance_mode boolean default false,
  updated_at timestamptz default now(),
  check (id = 1)
);
insert into public.app_settings (id, app_name, primary_color) values (1, 'RTN Chat', '#1877f2')
on conflict (id) do nothing;

-- Helper functions
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists(
    select 1 from public.friendships
    where (user_a = a and user_b = b) or (user_a = b and user_b = a)
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, username)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1), 'RTN User'),
    lower(regexp_replace(split_part(new.email, '@', 1), '[^a-zA-Z0-9_]', '', 'g')) || floor(random()*9999)::text
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Admin claim with code 2026. For production, change this code immediately.
create or replace function public.claim_first_admin(admin_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare admin_count int;
begin
  if auth.uid() is null then
    return 'not_logged_in';
  end if;
  if admin_code <> '2026' then
    return 'wrong_code';
  end if;
  select count(*) into admin_count from public.profiles where is_admin = true;
  if admin_count > 0 and not exists(select 1 from public.profiles where id = auth.uid() and is_admin = true) then
    return 'admin_already_exists';
  end if;
  update public.profiles set is_admin = true where id = auth.uid();
  return 'ok';
end;
$$;

create or replace function public.accept_friend_request(req_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare r record;
declare a uuid;
declare b uuid;
begin
  select * into r from public.friend_requests where id = req_id;
  if not found then return 'not_found'; end if;
  if r.to_id <> auth.uid() then return 'not_allowed'; end if;
  update public.friend_requests set status = 'accepted', updated_at = now() where id = req_id;
  if r.from_id::text < r.to_id::text then
    a := r.from_id;
    b := r.to_id;
  else
    a := r.to_id;
    b := r.from_id;
  end if;
  insert into public.friendships(user_a, user_b) values (a, b) on conflict do nothing;
  insert into public.notifications(user_id, actor_id, type, title, body, data)
  values (r.from_id, r.to_id, 'friend_accept', 'Friend request accepted', 'Your friend request was accepted.', jsonb_build_object('user_id', r.to_id));
  return 'ok';
end;
$$;

-- Enable RLS
alter table public.profiles enable row level security;
alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.blocks enable row level security;
alter table public.notifications enable row level security;
alter table public.messages enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;
alter table public.stories enable row level security;
alter table public.story_views enable row level security;
alter table public.badge_requests enable row level security;
alter table public.reports enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_messages enable row level security;
alter table public.app_settings enable row level security;

-- Drop old policies safely
DO $$
DECLARE pol record;
BEGIN
  FOR pol IN SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname='public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', pol.policyname, pol.schemaname, pol.tablename);
  END LOOP;
END $$;

-- Profiles
create policy "profiles read all" on public.profiles for select using (true);
create policy "profiles insert own" on public.profiles for insert with check (id = auth.uid());
create policy "profiles update own or admin" on public.profiles for update using (id = auth.uid() or public.is_admin()) with check (id = auth.uid() or public.is_admin());

-- Friend requests
create policy "friend requests read own" on public.friend_requests for select using (from_id = auth.uid() or to_id = auth.uid() or public.is_admin());
create policy "friend requests insert own" on public.friend_requests for insert with check (from_id = auth.uid());
create policy "friend requests update receiver or admin" on public.friend_requests for update using (to_id = auth.uid() or from_id = auth.uid() or public.is_admin());
create policy "friend requests delete own" on public.friend_requests for delete using (from_id = auth.uid() or to_id = auth.uid() or public.is_admin());

-- Friendships
create policy "friendships read own" on public.friendships for select using (user_a = auth.uid() or user_b = auth.uid() or public.is_admin());
create policy "friendships insert via function or admin" on public.friendships for insert with check (public.is_admin());
create policy "friendships delete own or admin" on public.friendships for delete using (user_a = auth.uid() or user_b = auth.uid() or public.is_admin());

-- Blocks
create policy "blocks read own" on public.blocks for select using (blocker_id = auth.uid() or public.is_admin());
create policy "blocks insert own" on public.blocks for insert with check (blocker_id = auth.uid());
create policy "blocks delete own" on public.blocks for delete using (blocker_id = auth.uid() or public.is_admin());

-- Notifications
create policy "notifications read own" on public.notifications for select using (user_id = auth.uid() or public.is_admin());
create policy "notifications insert logged in" on public.notifications for insert with check (auth.uid() is not null);
create policy "notifications update own" on public.notifications for update using (user_id = auth.uid() or public.is_admin());
create policy "notifications delete own" on public.notifications for delete using (user_id = auth.uid() or public.is_admin());

-- Messages: admin cannot read chat by policy, per requirement.
create policy "messages read participants" on public.messages for select using (sender_id = auth.uid() or receiver_id = auth.uid());
create policy "messages insert sender" on public.messages for insert with check (sender_id = auth.uid());
create policy "messages update participants" on public.messages for update using (sender_id = auth.uid() or receiver_id = auth.uid());
create policy "messages delete participants" on public.messages for delete using (sender_id = auth.uid() or receiver_id = auth.uid());

-- Posts
create policy "posts read public and own and admin" on public.posts for select using (privacy='public' or user_id=auth.uid() or public.is_admin() or (privacy='friends' and public.are_friends(user_id, auth.uid())));
create policy "posts insert own" on public.posts for insert with check (user_id = auth.uid());
create policy "posts update own or admin" on public.posts for update using (user_id = auth.uid() or public.is_admin());
create policy "posts delete own or admin" on public.posts for delete using (user_id = auth.uid() or public.is_admin());

create policy "likes read all" on public.post_likes for select using (true);
create policy "likes insert own" on public.post_likes for insert with check (user_id = auth.uid());
create policy "likes update own" on public.post_likes for update using (user_id = auth.uid());
create policy "likes delete own" on public.post_likes for delete using (user_id = auth.uid() or public.is_admin());

create policy "comments read all" on public.post_comments for select using (true);
create policy "comments insert own" on public.post_comments for insert with check (user_id = auth.uid());
create policy "comments delete own or admin" on public.post_comments for delete using (user_id = auth.uid() or public.is_admin());

-- Stories
create policy "stories read active" on public.stories for select using (expires_at > now() or user_id = auth.uid() or public.is_admin());
create policy "stories insert own" on public.stories for insert with check (user_id = auth.uid());
create policy "stories delete own or admin" on public.stories for delete using (user_id = auth.uid() or public.is_admin());

create policy "story views read own story or own view" on public.story_views for select using (user_id = auth.uid() or exists(select 1 from public.stories s where s.id=story_id and s.user_id=auth.uid()) or public.is_admin());
create policy "story views insert own" on public.story_views for insert with check (user_id = auth.uid());
create policy "story views update own" on public.story_views for update using (user_id = auth.uid());

-- Badge and reports
create policy "badge read own or admin" on public.badge_requests for select using (user_id = auth.uid() or public.is_admin());
create policy "badge insert own" on public.badge_requests for insert with check (user_id = auth.uid());
create policy "badge update admin" on public.badge_requests for update using (public.is_admin());

create policy "reports read own or admin" on public.reports for select using (reporter_id = auth.uid() or public.is_admin());
create policy "reports insert own" on public.reports for insert with check (reporter_id = auth.uid());
create policy "reports update admin" on public.reports for update using (public.is_admin());

-- Groups basic
create policy "groups read member or admin" on public.groups for select using (public.is_admin() or exists(select 1 from public.group_members gm where gm.group_id=id and gm.user_id=auth.uid()));
create policy "groups insert own" on public.groups for insert with check (owner_id = auth.uid());
create policy "groups update owner or admin" on public.groups for update using (owner_id = auth.uid() or public.is_admin());
create policy "groups delete owner or admin" on public.groups for delete using (owner_id = auth.uid() or public.is_admin());

create policy "group members read same group" on public.group_members for select using (public.is_admin() or user_id=auth.uid() or exists(select 1 from public.group_members gm where gm.group_id=group_id and gm.user_id=auth.uid()));
create policy "group members insert owner or self" on public.group_members for insert with check (user_id=auth.uid() or public.is_admin() or exists(select 1 from public.groups g where g.id=group_id and g.owner_id=auth.uid()));
create policy "group members delete own or owner" on public.group_members for delete using (user_id=auth.uid() or public.is_admin() or exists(select 1 from public.groups g where g.id=group_id and g.owner_id=auth.uid()));

create policy "group messages read members" on public.group_messages for select using (exists(select 1 from public.group_members gm where gm.group_id=group_id and gm.user_id=auth.uid()) or public.is_admin());
create policy "group messages insert members" on public.group_messages for insert with check (sender_id=auth.uid() and exists(select 1 from public.group_members gm where gm.group_id=group_id and gm.user_id=auth.uid()));
create policy "group messages delete sender or admin" on public.group_messages for delete using (sender_id=auth.uid() or public.is_admin());

-- Settings
create policy "settings read all" on public.app_settings for select using (true);
create policy "settings update admin" on public.app_settings for update using (public.is_admin());

-- Storage buckets
insert into storage.buckets (id, name, public) values
('avatars','avatars',true),
('covers','covers',true),
('posts','posts',true),
('stories','stories',true),
('chat-files','chat-files',true),
('group-icons','group-icons',true),
('app-assets','app-assets',true)
on conflict (id) do nothing;

-- Storage policies. Public demo: authenticated users can upload, public can read.
drop policy if exists "storage read avatars" on storage.objects;
drop policy if exists "storage upload authenticated" on storage.objects;
drop policy if exists "storage update own" on storage.objects;
drop policy if exists "storage delete own" on storage.objects;
create policy "storage read avatars" on storage.objects for select using (bucket_id in ('avatars','covers','posts','stories','chat-files','group-icons','app-assets'));
create policy "storage upload authenticated" on storage.objects for insert with check (auth.uid() is not null and bucket_id in ('avatars','covers','posts','stories','chat-files','group-icons','app-assets'));
create policy "storage update own" on storage.objects for update using (auth.uid()::text = (storage.foldername(name))[1] or public.is_admin());
create policy "storage delete own" on storage.objects for delete using (auth.uid()::text = (storage.foldername(name))[1] or public.is_admin());

-- Realtime publication. Safe to run multiple times.
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.friend_requests;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.friendships;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.post_likes;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.post_comments;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.stories;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.badge_requests;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

