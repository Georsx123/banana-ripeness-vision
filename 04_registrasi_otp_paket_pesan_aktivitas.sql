-- =====================================================================
-- TAMBAHAN 4: registrasi OTP di awal, paket user (batas scan), pesan admin,
--             riwayat aktivitas admin, dan perapian keamanan.
-- Jalankan SETELAH 01 dan 03. Aman dijalankan ulang.
-- Supabase > SQL Editor > New query > paste semua > Run
-- =====================================================================

-- ---------- 1. Kolom baru di profiles ----------
alter table public.profiles add column if not exists plan text not null default 'reguler'
  check (plan in ('reguler', 'vip', 'premium'));
alter table public.profiles add column if not exists profil_lengkap boolean not null default false;

-- Akun yang sudah ada sebelum fitur ini dianggap lengkap
update public.profiles set profil_lengkap = true
 where profil_lengkap = false and username !~ '^u[0-9a-f]{12}$';

-- ---------- 2. Batas scan per paket (ubah angkanya di sini bila perlu) ----------
create or replace function public.plan_limit(p text) returns int
language sql immutable as $$
  select case lower(coalesce(p, '')) when 'premium' then 100 when 'vip' then 50 else 10 end;
$$;

-- ---------- 3. Pengguna biasa tidak boleh mengubah role, paket, dan email sendiri ----------
create or replace function public.profiles_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.role := old.role;
    new.plan := old.plan;
    new.email := old.email;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_guard on public.profiles;
create trigger trg_profiles_guard before update on public.profiles
  for each row execute function public.profiles_guard();

-- ---------- 4. Profil otomatis saat akun dibuat (username sementara bila belum diisi) ----------
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, nama, username, no_telp, jenis_kelamin, role, email)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'nama', ''), 'Pengguna'),
    coalesce(nullif(lower(new.raw_user_meta_data->>'username'), ''), 'u' || substr(replace(new.id::text, '-', ''), 1, 12)),
    coalesce(new.raw_user_meta_data->>'no_telp', ''),
    coalesce(new.raw_user_meta_data->>'jenis_kelamin', ''),
    'user',
    lower(new.email)
  );
  return new;
end;
$$;

-- ---------- 5. Fungsi pencarian akun (registrasi dan lupa password) ----------
create or replace function public.email_registered(p_email text) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.profiles
                  where profil_lengkap and lower(email) = lower(trim(p_email)));
$$;

create or replace function public.account_email(p_identifier text) returns text
language sql security definer stable set search_path = public as $$
  select email from public.profiles
   where profil_lengkap
     and (lower(username) = lower(trim(p_identifier)) or lower(email) = lower(trim(p_identifier)))
   limit 1;
$$;

grant execute on function public.email_registered(text) to anon, authenticated;
grant execute on function public.account_email(text) to anon, authenticated;

-- ---------- 6. Admin menambah pengguna: terverifikasi dan profil lengkap ----------
create or replace function public.admin_confirm_user(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  update auth.users set email_confirmed_at = coalesce(email_confirmed_at, now()) where id = p_id;
  update public.profiles set profil_lengkap = true where id = p_id;
end;
$$;

-- ---------- 7. Hitungan scan harian ----------
create table if not exists public.scan_usage (
  user_id uuid not null references public.profiles(id) on delete cascade,
  tanggal date not null,
  jumlah int not null default 0,
  primary key (user_id, tanggal)
);
alter table public.scan_usage enable row level security;
-- Tanpa policy: hanya bisa diubah lewat fungsi di bawah.

create or replace function public.consume_scan(p_user uuid) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_role text; v_plan text; v_limit int; v_used int;
  v_today date := (now() at time zone 'Asia/Jakarta')::date;
begin
  select role, plan into v_role, v_plan from public.profiles where id = p_user;
  if v_role is null then
    return json_build_object('allowed', false, 'plan', 'reguler', 'used', 0, 'limit', 0, 'unlimited', false, 'remaining', 0);
  end if;
  if v_role = 'admin' then
    return json_build_object('allowed', true, 'plan', 'admin', 'used', 0, 'limit', 0, 'unlimited', true, 'remaining', 0);
  end if;
  v_limit := public.plan_limit(v_plan);
  insert into public.scan_usage (user_id, tanggal, jumlah) values (p_user, v_today, 0)
    on conflict (user_id, tanggal) do nothing;
  update public.scan_usage set jumlah = jumlah + 1
   where user_id = p_user and tanggal = v_today and jumlah < v_limit
  returning jumlah into v_used;
  if v_used is null then
    return json_build_object('allowed', false, 'plan', v_plan, 'used', v_limit, 'limit', v_limit, 'unlimited', false, 'remaining', 0);
  end if;
  return json_build_object('allowed', true, 'plan', v_plan, 'used', v_used, 'limit', v_limit, 'unlimited', false, 'remaining', v_limit - v_used);
end;
$$;

create or replace function public.refund_scan(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.scan_usage set jumlah = greatest(jumlah - 1, 0)
   where user_id = p_user and tanggal = (now() at time zone 'Asia/Jakarta')::date;
end;
$$;

-- Dua fungsi ini HANYA boleh dipanggil oleh fungsi server (service_role), bukan oleh pengguna.
revoke all on function public.consume_scan(uuid) from public, anon, authenticated;
revoke all on function public.refund_scan(uuid) from public, anon, authenticated;
grant execute on function public.consume_scan(uuid) to service_role;
grant execute on function public.refund_scan(uuid) to service_role;

-- Sisa scan milik pengguna yang sedang login
create or replace function public.my_quota() returns json
language plpgsql security definer stable set search_path = public as $$
declare
  v_role text; v_plan text; v_limit int; v_used int;
  v_today date := (now() at time zone 'Asia/Jakarta')::date;
begin
  select role, plan into v_role, v_plan from public.profiles where id = auth.uid();
  if v_role is null then return null; end if;
  if v_role = 'admin' then
    return json_build_object('plan', 'admin', 'used', 0, 'limit', 0, 'unlimited', true, 'remaining', 0);
  end if;
  v_limit := public.plan_limit(v_plan);
  select coalesce(jumlah, 0) into v_used from public.scan_usage where user_id = auth.uid() and tanggal = v_today;
  v_used := coalesce(v_used, 0);
  return json_build_object('plan', v_plan, 'used', v_used, 'limit', v_limit, 'unlimited', false, 'remaining', greatest(v_limit - v_used, 0));
end;
$$;
grant execute on function public.my_quota() to authenticated;

-- ---------- 8. Pesan (catatan) admin ----------
create table if not exists public.admin_pesan (
  id bigint generated always as identity primary key,
  isi text not null,
  dibuat_oleh uuid references public.profiles(id) on delete set null,
  dibuat_nama text not null default '',
  created_at timestamptz not null default now()
);
alter table public.admin_pesan enable row level security;
drop policy if exists admin_pesan_all on public.admin_pesan;
create policy admin_pesan_all on public.admin_pesan for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------- 9. Riwayat aktivitas admin ----------
create table if not exists public.admin_log (
  id bigint generated always as identity primary key,
  admin_id uuid references public.profiles(id) on delete set null,
  admin_nama text not null default '',
  aksi text not null,
  detail text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists idx_admin_log_waktu on public.admin_log (created_at desc);
alter table public.admin_log enable row level security;

drop policy if exists admin_log_read on public.admin_log;
create policy admin_log_read on public.admin_log for select to authenticated using (public.is_admin());
drop policy if exists admin_log_insert on public.admin_log;
create policy admin_log_insert on public.admin_log for insert to authenticated
  with check (public.is_admin() and admin_id = auth.uid());
drop policy if exists admin_log_delete on public.admin_log;
create policy admin_log_delete on public.admin_log for delete to authenticated using (public.is_admin());

-- ---------- 10. Hapus fitur reset lewat no. telepon (tidak aman bila tetap bisa dipanggil) ----------
drop function if exists public.reset_password_by_phone(text, text, text);

-- ---------- 11. Pembersihan akun yang tidak diselesaikan (verifikasi email tapi tidak melengkapi data) ----------
create or replace function public.cleanup_incomplete_users() returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  with d as (
    delete from auth.users
     where id in (select id from public.profiles
                   where not profil_lengkap and created_at < now() - interval '1 day')
    returning 1
  )
  select count(*) into n from d;
  return n;
end;
$$;
revoke all on function public.cleanup_incomplete_users() from public, anon, authenticated;

-- OPSIONAL: jalankan otomatis tiap hari jam 03.00 UTC.
-- Aktifkan dulu ekstensi: Supabase > Database > Extensions > pg_cron. Lalu jalankan (hapus tanda --):
-- select cron.schedule('bersihkan-akun-belum-lengkap', '0 3 * * *', $$select public.cleanup_incomplete_users()$$);
-- Atau jalankan manual kapan saja:  select public.cleanup_incomplete_users();

-- ---------- 12. Statistik admin: hanya menghitung akun yang sudah lengkap ----------
create or replace function public.admin_stats() returns json
language plpgsql security definer set search_path = public as $$
declare r json;
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  select json_build_object(
    'total_user', (select count(*) from public.profiles where profil_lengkap),
    'total_admin', (select count(*) from public.profiles where role = 'admin'),
    'total_scan', (select count(distinct (user_id, created_at)) from public.riwayat_scan),
    'scan_hari_ini', (select count(distinct (user_id, created_at)) from public.riwayat_scan
        where (created_at at time zone 'Asia/Jakarta')::date = (now() at time zone 'Asia/Jakarta')::date),
    'per_kelas', (select coalesce(json_object_agg(kelas, c), '{}'::json)
        from (select kelas, sum(jumlah_objek) c from public.riwayat_scan group by kelas) t),
    'per_gender', (select coalesce(json_object_agg(g, c), '{}'::json)
        from (select coalesce(nullif(jenis_kelamin,''),'Tidak diisi') g, count(*) c from public.profiles where profil_lengkap group by 1) t),
    'per_hari', (select coalesce(json_agg(json_build_object('label', to_char(d,'DD/MM'), 'jumlah', c) order by d), '[]'::json)
        from (
          select gs::date d,
                 (select count(distinct (user_id, created_at)) from public.riwayat_scan
                   where (created_at at time zone 'Asia/Jakarta')::date = gs::date) c
          from generate_series((now() at time zone 'Asia/Jakarta')::date - 6,
                               (now() at time zone 'Asia/Jakarta')::date, interval '1 day') gs
        ) t)
  ) into r;
  return r;
end;
$$;
