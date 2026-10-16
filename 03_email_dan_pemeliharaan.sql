-- =====================================================================
-- TAMBAHAN: EMAIL ASLI + MODE PEMELIHARAAN
-- Jalankan SETELAH 01_database.sql. Aman dijalankan ulang.
-- Supabase > SQL Editor > New query > paste semua > Run
-- =====================================================================

-- ---------- 1. Kolom email di profiles ----------
alter table public.profiles add column if not exists email text;

update public.profiles p
   set email = lower(u.email)
  from auth.users u
 where u.id = p.id and (p.email is null or p.email = '');

create index if not exists idx_profiles_email on public.profiles (lower(email));

-- ---------- 2. Profil otomatis menyimpan email saat registrasi ----------
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, nama, username, no_telp, jenis_kelamin, role, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nama', 'Pengguna'),
    lower(coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1))),
    coalesce(new.raw_user_meta_data->>'no_telp', ''),
    coalesce(new.raw_user_meta_data->>'jenis_kelamin', ''),
    'user',
    lower(new.email)
  );
  return new;
end;
$$;

-- ---------- 3. Cek ketersediaan username (dipakai saat registrasi) ----------
create or replace function public.username_available(p_username text) returns boolean
language sql security definer stable set search_path = public as $$
  select not exists (select 1 from public.profiles where lower(username) = lower(trim(p_username)));
$$;

-- ---------- 4. Login dengan username: cari email dari username ----------
-- CATATAN KEAMANAN: fungsi ini membuat email seseorang bisa diketahui oleh orang yang
-- menebak username-nya. Kalau tidak mau, hapus fungsi ini dan login hanya lewat email.
create or replace function public.login_email(p_username text) returns text
language sql security definer stable set search_path = public as $$
  select email from public.profiles where lower(username) = lower(trim(p_username)) limit 1;
$$;

grant execute on function public.username_available(text) to anon, authenticated;
grant execute on function public.login_email(text) to anon, authenticated;

-- ---------- 5. Admin menambah pengguna: langsung dianggap terverifikasi ----------
create or replace function public.admin_confirm_user(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  update auth.users set email_confirmed_at = coalesce(email_confirmed_at, now()) where id = p_id;
end;
$$;

-- ---------- 6. Pengaturan aplikasi (mode pemeliharaan) ----------
create table if not exists public.app_settings (
  key text primary key,
  value text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.app_settings enable row level security;

drop policy if exists app_settings_read on public.app_settings;
create policy app_settings_read on public.app_settings for select to authenticated using (true);

drop policy if exists app_settings_admin on public.app_settings;
create policy app_settings_admin on public.app_settings for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

insert into public.app_settings (key, value) values
  ('maintenance', 'off'),
  ('maintenance_message', 'Fitur scan sedang istirahat sementara. Silakan coba lagi nanti.')
on conflict (key) do nothing;
