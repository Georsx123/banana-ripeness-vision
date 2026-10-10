-- =====================================================================
-- PISANG SCAN - SKRIP DATABASE (Supabase / PostgreSQL)
-- Cara pakai: Supabase > SQL Editor > New query > paste semua > Run
-- Aman dijalankan ulang.
-- =====================================================================

-- ---------- TABEL 1: profiles (data pengguna) ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nama text not null,
  username text not null unique,
  no_telp text not null default '',
  jenis_kelamin text not null default '' check (jenis_kelamin in ('Laki-laki','Perempuan','')),
  role text not null default 'user' check (role in ('admin','user')),
  created_at timestamptz not null default now()
);

-- ---------- TABEL 2: riwayat_scan ----------
create table if not exists public.riwayat_scan (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  mode text not null check (mode in ('gambar','realtime')),
  kelas text not null,
  akurasi numeric(5,2) not null default 0,
  jumlah_objek int not null default 1,
  created_at timestamptz not null default now()
);
create index if not exists idx_riwayat_user on public.riwayat_scan(user_id, created_at desc);

-- ---------- TABEL 3: info_pisang (konten dashboard, dikelola admin) ----------
create table if not exists public.info_pisang (
  id bigint generated always as identity primary key,
  kategori text not null default 'fakta' check (kategori in ('fakta','info','tips')),
  judul text not null,
  isi text not null,
  aktif boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------- FUNGSI BANTU ----------
create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function public.my_role() returns text
language sql security definer stable set search_path = public as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.norm_phone(p text) returns text
language sql immutable as $$
  select regexp_replace(regexp_replace(coalesce(p,''), '\D', '', 'g'), '^62', '0');
$$;

-- ---------- OTOMATIS BUAT PROFIL SAAT REGISTRASI ----------
-- Role SELALU 'user'. Admin hanya bisa dibuat lewat SQL (lihat 02_jadikan_admin.sql).
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, nama, username, no_telp, jenis_kelamin, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nama', 'Pengguna'),
    lower(coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1))),
    coalesce(new.raw_user_meta_data->>'no_telp', ''),
    coalesce(new.raw_user_meta_data->>'jenis_kelamin', ''),
    'user'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- KEAMANAN (Row Level Security) ----------
alter table public.profiles enable row level security;
alter table public.riwayat_scan enable row level security;
alter table public.info_pisang enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid() and role = public.my_role());

drop policy if exists profiles_update_admin on public.profiles;
create policy profiles_update_admin on public.profiles for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists riwayat_select on public.riwayat_scan;
create policy riwayat_select on public.riwayat_scan for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists riwayat_insert on public.riwayat_scan;
create policy riwayat_insert on public.riwayat_scan for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists riwayat_delete on public.riwayat_scan;
create policy riwayat_delete on public.riwayat_scan for delete to authenticated
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists info_select on public.info_pisang;
create policy info_select on public.info_pisang for select to authenticated
  using (aktif = true or public.is_admin());

drop policy if exists info_admin on public.info_pisang;
create policy info_admin on public.info_pisang for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------- LUPA PASSWORD (opsi A: username + no. telepon) ----------
-- Akun admin sengaja TIDAK bisa direset lewat fitur ini.
create or replace function public.reset_password_by_phone(p_username text, p_phone text, p_new_password text)
returns boolean
language plpgsql security definer set search_path = public, extensions as $$
declare v_id uuid;
begin
  if length(coalesce(p_new_password,'')) < 6 then
    raise exception 'Password minimal 6 karakter';
  end if;
  select id into v_id from public.profiles
   where lower(username) = lower(trim(p_username))
     and role <> 'admin'
     and public.norm_phone(no_telp) = public.norm_phone(p_phone)
     and public.norm_phone(no_telp) <> ''
   limit 1;
  if v_id is null then
    return false;
  end if;
  update auth.users
     set encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf', 10)),
         updated_at = now()
   where id = v_id;
  return true;
end;
$$;

-- ---------- FUNGSI KHUSUS ADMIN ----------
create or replace function public.admin_delete_user(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  if p_id = auth.uid() then raise exception 'Tidak bisa menghapus akun sendiri'; end if;
  delete from auth.users where id = p_id;
end;
$$;

create or replace function public.admin_reset_password(p_id uuid, p_new_password text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  if length(coalesce(p_new_password,'')) < 6 then raise exception 'Password minimal 6 karakter'; end if;
  update auth.users
     set encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf', 10)),
         updated_at = now()
   where id = p_id;
end;
$$;

create or replace function public.admin_stats() returns json
language plpgsql security definer set search_path = public as $$
declare r json;
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  select json_build_object(
    'total_user', (select count(*) from public.profiles),
    'total_admin', (select count(*) from public.profiles where role = 'admin'),
    'total_scan', (select count(distinct (user_id, created_at)) from public.riwayat_scan),
    'scan_hari_ini', (select count(distinct (user_id, created_at)) from public.riwayat_scan
        where (created_at at time zone 'Asia/Jakarta')::date = (now() at time zone 'Asia/Jakarta')::date),
    'per_kelas', (select coalesce(json_object_agg(kelas, c), '{}'::json)
        from (select kelas, sum(jumlah_objek) c from public.riwayat_scan group by kelas) t),
    'per_gender', (select coalesce(json_object_agg(g, c), '{}'::json)
        from (select coalesce(nullif(jenis_kelamin,''),'Tidak diisi') g, count(*) c from public.profiles group by 1) t),
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

-- ---------- DATA AWAL UNTUK DASHBOARD ----------
insert into public.info_pisang (kategori, judul, isi)
select * from (values
  ('fakta','Pisang itu buah berry','Secara botani, pisang termasuk buah berry, sedangkan stroberi justru bukan. Unik, bukan?'),
  ('fakta','Pohon pisang bukan pohon','Yang disebut batang pisang sebenarnya batang semu dari pelepah daun. Pohon pisang adalah herba raksasa.'),
  ('fakta','Si penyebab buah lain cepat matang','Pisang matang melepaskan gas etilen yang mempercepat pematangan buah di dekatnya, seperti alpukat dan tomat.'),
  ('fakta','Kaya kalium','Setiap 100 gram pisang mengandung sekitar 350 mg kalium yang baik untuk otot dan jantung.'),
  ('info','Pati berubah jadi gula','Saat pisang matang, pati diubah menjadi gula sederhana sehingga rasanya makin manis dan lebih mudah dicerna.'),
  ('info','Bintik cokelat tanda sangat matang','Bintik cokelat di kulit menandakan pisang sudah sangat matang dan paling manis. Cocok untuk kue dan smoothie.'),
  ('info','Waspadai pisang busuk','Pisang berjamur, berbau fermentasi, atau berair sebaiknya dibuang dan tidak dikonsumsi.'),
  ('tips','Perlambat pematangan','Bungkus tangkai pisang dengan plastik wrap dan jauhkan dari buah lain agar tidak cepat matang.'),
  ('tips','Selamatkan pisang terlalu matang','Kupas lalu bekukan pisang yang terlalu matang untuk smoothie atau banana bread.'),
  ('tips','Percepat pematangan','Masukkan pisang mentah ke kantong kertas bersama apel agar lebih cepat matang.')
) as v(kategori, judul, isi)
where not exists (select 1 from public.info_pisang);
