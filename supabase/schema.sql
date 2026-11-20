create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nama text not null default '',
  email text not null default '',
  nim text unique,
  prodi text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.jadwal (
  id text primary key default gen_random_uuid()::text,
  user_id uuid not null references auth.users (id) on delete cascade,
  mata_kuliah text not null,
  jam_mulai text not null,
  jam_selesai text not null,
  ruangan text not null,
  dosen text not null,
  hari text not null,
  tanggal text not null,
  is_alarm_active boolean not null default true,
  alarm_minutes_before integer not null default 10,
  alarm_minutes_list integer[] not null default array[10],
  created_at timestamptz not null default now()
);

create table if not exists public.catatan (
  id text primary key default gen_random_uuid()::text,
  user_id uuid not null references auth.users (id) on delete cascade,
  jadwal_id text,
  mata_kuliah text not null,
  minggu_ke integer not null default 1,
  judul text not null,
  isi text not null,
  tanggal text not null,
  waktu text not null,
  tipe text not null,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.jadwal enable row level security;
alter table public.catatan enable row level security;

drop policy if exists "Users manage their own profile" on public.profiles;
create policy "Users manage their own profile"
  on public.profiles for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "Users manage their own schedules" on public.jadwal;
create policy "Users manage their own schedules"
  on public.jadwal for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users manage their own notes" on public.catatan;
create policy "Users manage their own notes"
  on public.catatan for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, nama, email, nim, prodi)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nama', new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.email, ''),
    nullif(new.raw_user_meta_data ->> 'nim', ''),
    coalesce(new.raw_user_meta_data ->> 'prodi', '')
  )
  on conflict (id) do update set
    nama = excluded.nama,
    email = excluded.email,
    nim = coalesce(excluded.nim, public.profiles.nim),
    prodi = excluded.prodi;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
