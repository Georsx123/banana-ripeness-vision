-- =====================================================================
-- TAMBAHAN 5: izin dua admin, pesan/permintaan otomatis, plan admin, hapus info_pisang.
-- Jalankan SETELAH 01, 03, dan 04. Aman dijalankan ulang.
-- PENTING: JANGAN jalankan ulang 01_database.sql setelah ini. File 01 berisi versi lama
-- beberapa fungsi dan akan mengembalikan aturan lama (termasuk tabel info_pisang).
-- Supabase > SQL Editor > New query > paste semua > Run
-- =====================================================================

-- ---------- 1. Tabel info_pisang dihapus (isinya kini tertulis di aplikasi) ----------
drop table if exists public.info_pisang cascade;

-- ---------- 2. Kolom plan: akun admin bernilai 'admin' ----------
alter table public.profiles drop constraint if exists profiles_plan_check;
alter table public.profiles add constraint profiles_plan_check
  check (plan in ('reguler', 'vip', 'premium', 'admin'));
update public.profiles set plan = 'admin' where role = 'admin' and plan <> 'admin';
update public.profiles set plan = 'reguler' where role <> 'admin' and plan = 'admin';

-- Plan selalu mengikuti role (juga bila role diubah lewat Table Editor / SQL)
create or replace function public.profiles_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.role := old.role;
    new.plan := old.plan;
    new.email := old.email;
  end if;
  if new.role = 'admin' then
    new.plan := 'admin';
  elsif new.plan = 'admin' then
    new.plan := 'reguler';
  end if;
  return new;
end;
$$;

-- ---------- 3. Permintaan izin antar admin ----------
create table if not exists public.admin_request (
  id bigint generated always as identity primary key,
  jenis text not null check (jenis in ('edit_user', 'reset_password', 'delete_user', 'clear_log')),
  target_id uuid,
  target_label text not null default '',
  detail text not null default '',
  alasan text not null,
  dibuat_oleh uuid references public.profiles(id) on delete set null,
  dibuat_nama text not null default '',
  status text not null default 'menunggu'
    check (status in ('menunggu', 'disetujui', 'ditolak', 'dibatalkan', 'dipakai')),
  diputus_oleh uuid references public.profiles(id) on delete set null,
  diputus_nama text not null default '',
  diputus_pada timestamptz,
  catatan_keputusan text not null default '',
  dipakai_pada timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_admin_request_status on public.admin_request (status, created_at desc);
alter table public.admin_request enable row level security;
drop policy if exists admin_request_read on public.admin_request;
create policy admin_request_read on public.admin_request for select to authenticated using (public.is_admin());
-- Sengaja tanpa policy insert/update/delete: hanya bisa lewat fungsi di bawah.

-- Penanda "terakhir melihat menu Pesan" per admin (untuk titik notifikasi)
create table if not exists public.admin_state (
  admin_id uuid primary key references public.profiles(id) on delete cascade,
  pesan_dilihat timestamptz not null default now()
);
alter table public.admin_state enable row level security;

-- ---------- 4. Fungsi bantu (internal) ----------
create or replace function public.admin_log_add(p_aksi text, p_detail text) returns void
language plpgsql security definer set search_path = public as $$
declare v_nama text;
begin
  select nama into v_nama from public.profiles where id = auth.uid();
  insert into public.admin_log (admin_id, admin_nama, aksi, detail)
  values (auth.uid(), coalesce(v_nama, ''), p_aksi, p_detail);
end;
$$;
revoke all on function public.admin_log_add(text, text) from public, anon, authenticated;

-- Memakai satu izin yang sudah disetujui (sekali pakai, berlaku 1 jam setelah disetujui)
create or replace function public.use_admin_grant(p_request bigint, p_jenis text, p_target uuid)
returns public.admin_request
language plpgsql security definer set search_path = public as $$
declare r public.admin_request;
begin
  update public.admin_request
     set status = 'dipakai', dipakai_pada = now()
   where id = p_request
     and dibuat_oleh = auth.uid()
     and jenis = p_jenis
     and target_id is not distinct from p_target
     and status = 'disetujui'
     and diputus_pada > now() - interval '1 hour'
  returning * into r;
  if r.id is null then
    raise exception 'Izin tidak ada, belum disetujui, sudah dipakai, atau sudah kedaluwarsa';
  end if;
  return r;
end;
$$;
revoke all on function public.use_admin_grant(bigint, text, uuid) from public, anon, authenticated;

-- ---------- 5. Mengajukan, memutuskan, dan membatalkan permintaan ----------
create or replace function public.request_admin_action(
  p_jenis text, p_target uuid, p_label text, p_detail text, p_alasan text
) returns bigint
language plpgsql security definer set search_path = public as $$
declare v_id bigint; v_nama text;
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 3 then raise exception 'Alasan wajib diisi'; end if;
  if exists (
    select 1 from public.admin_request
     where dibuat_oleh = auth.uid() and jenis = p_jenis and target_id is not distinct from p_target
       and (status = 'menunggu' or (status = 'disetujui' and diputus_pada > now() - interval '1 hour'))
  ) then
    raise exception 'Sudah ada permintaan yang masih berlaku untuk aksi ini';
  end if;
  select nama into v_nama from public.profiles where id = auth.uid();
  insert into public.admin_request (jenis, target_id, target_label, detail, alasan, dibuat_oleh, dibuat_nama)
  values (p_jenis, p_target, coalesce(p_label, ''), coalesce(p_detail, ''), trim(p_alasan), auth.uid(), coalesce(v_nama, ''))
  returning id into v_id;
  perform public.admin_log_add('Ajukan permintaan izin', coalesce(p_detail, '') || ' | Alasan: ' || trim(p_alasan));
  return v_id;
end;
$$;

create or replace function public.decide_admin_request(p_id bigint, p_setuju boolean, p_catatan text)
returns void
language plpgsql security definer set search_path = public as $$
declare r public.admin_request; v_nama text;
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  select * into r from public.admin_request where id = p_id for update;
  if not found then raise exception 'Permintaan tidak ditemukan'; end if;
  if r.status <> 'menunggu' then raise exception 'Permintaan ini sudah diproses'; end if;
  if r.dibuat_oleh = auth.uid() then raise exception 'Tidak bisa menyetujui permintaan sendiri'; end if;
  select nama into v_nama from public.profiles where id = auth.uid();
  update public.admin_request
     set status = case when p_setuju then 'disetujui' else 'ditolak' end,
         diputus_oleh = auth.uid(), diputus_nama = coalesce(v_nama, ''), diputus_pada = now(),
         catatan_keputusan = coalesce(trim(p_catatan), '')
   where id = p_id;
  perform public.admin_log_add(
    case when p_setuju then 'Setujui permintaan izin' else 'Tolak permintaan izin' end,
    r.detail || ' (pemohon: ' || r.dibuat_nama || ')'
      || case when coalesce(trim(p_catatan), '') <> '' then ' | Catatan: ' || trim(p_catatan) else '' end
  );
end;
$$;

create or replace function public.cancel_admin_request(p_id bigint) returns void
language plpgsql security definer set search_path = public as $$
declare r public.admin_request;
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  update public.admin_request set status = 'dibatalkan'
   where id = p_id and dibuat_oleh = auth.uid() and status in ('menunggu', 'disetujui')
  returning * into r;
  if r.id is null then raise exception 'Permintaan tidak bisa dibatalkan'; end if;
  perform public.admin_log_add('Batalkan permintaan izin', r.detail);
end;
$$;

-- ---------- 6. Aksi sensitif: butuh izin yang sudah disetujui admin lain ----------
create or replace function public.admin_edit_user(
  p_id uuid, p_nama text, p_no_telp text, p_gender text, p_role text, p_plan text, p_request bigint
) returns void
language plpgsql security definer set search_path = public as $$
declare r public.admin_request; v_user text; v_plan text;
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  r := public.use_admin_grant(p_request, 'edit_user', p_id);
  select username into v_user from public.profiles where id = p_id;
  if v_user is null then raise exception 'Pengguna tidak ditemukan'; end if;
  if p_id = auth.uid() and p_role <> 'admin' then raise exception 'Tidak bisa menurunkan role akun sendiri'; end if;
  v_plan := case when p_role = 'admin' then 'admin' when p_plan in ('vip', 'premium') then p_plan else 'reguler' end;
  update public.profiles
     set nama = trim(p_nama), no_telp = trim(p_no_telp), jenis_kelamin = p_gender, role = p_role, plan = v_plan
   where id = p_id;
  perform public.admin_log_add('Ubah data pengguna',
    '@' || v_user || ' - role ' || p_role || ' - paket ' || v_plan
    || ' (izin #' || r.id || ' dari ' || r.diputus_nama || ')');
end;
$$;

drop function if exists public.admin_delete_user(uuid);
create or replace function public.admin_delete_user(p_id uuid, p_request bigint) returns void
language plpgsql security definer set search_path = public as $$
declare r public.admin_request; v_user text;
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  if p_id = auth.uid() then raise exception 'Tidak bisa menghapus akun sendiri'; end if;
  r := public.use_admin_grant(p_request, 'delete_user', p_id);
  select username into v_user from public.profiles where id = p_id;
  delete from auth.users where id = p_id;
  perform public.admin_log_add('Hapus pengguna',
    '@' || coalesce(v_user, '?') || ' (izin #' || r.id || ' dari ' || r.diputus_nama || ')');
end;
$$;

drop function if exists public.admin_reset_password(uuid, text);
create or replace function public.admin_reset_password(p_id uuid, p_new_password text, p_request bigint)
returns void
language plpgsql security definer set search_path = public, extensions as $$
declare r public.admin_request; v_user text;
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  if length(coalesce(p_new_password, '')) < 6 then raise exception 'Password minimal 6 karakter'; end if;
  r := public.use_admin_grant(p_request, 'reset_password', p_id);
  select username into v_user from public.profiles where id = p_id;
  update auth.users
     set encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf', 10)),
         updated_at = now()
   where id = p_id;
  perform public.admin_log_add('Reset password pengguna',
    '@' || coalesce(v_user, '?') || ' (izin #' || r.id || ' dari ' || r.diputus_nama || ')');
end;
$$;

create or replace function public.clear_admin_log(p_request bigint) returns void
language plpgsql security definer set search_path = public as $$
declare r public.admin_request;
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  r := public.use_admin_grant(p_request, 'clear_log', null);
  delete from public.admin_log where true;
  perform public.admin_log_add('Bersihkan riwayat aktivitas',
    'Seluruh catatan sebelumnya dihapus (izin #' || r.id || ' dari ' || r.diputus_nama || ')');
end;
$$;

-- Tutup jalur langsung (tanpa izin)
drop policy if exists profiles_update_admin on public.profiles;
drop policy if exists admin_log_delete on public.admin_log;

-- ---------- 7. Notifikasi menu Pesan ----------
create or replace function public.pesan_dilihat() returns timestamptz
language sql security definer stable set search_path = public as $$
  select coalesce((select pesan_dilihat from public.admin_state where admin_id = auth.uid()), 'epoch'::timestamptz);
$$;

create or replace function public.tandai_pesan_dibaca() returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then return; end if;
  insert into public.admin_state (admin_id, pesan_dilihat) values (auth.uid(), now())
  on conflict (admin_id) do update set pesan_dilihat = now();
end;
$$;

create or replace function public.pesan_ringkas() returns json
language plpgsql security definer stable set search_path = public as $$
declare v_seen timestamptz := public.pesan_dilihat();
begin
  if not public.is_admin() then
    return json_build_object('baru', 0, 'perlu_tindakan', 0, 'disetujui_saya', 0);
  end if;
  return json_build_object(
    'baru',
      (select count(*) from public.admin_pesan where dibuat_oleh is distinct from auth.uid() and created_at > v_seen)
      + (select count(*) from public.admin_request where dibuat_oleh is distinct from auth.uid() and created_at > v_seen)
      + (select count(*) from public.admin_request where dibuat_oleh = auth.uid() and diputus_pada > v_seen),
    'perlu_tindakan',
      (select count(*) from public.admin_request where status = 'menunggu' and dibuat_oleh is distinct from auth.uid()),
    'disetujui_saya',
      (select count(*) from public.admin_request
        where dibuat_oleh = auth.uid() and status = 'disetujui' and diputus_pada > v_seen)
  );
end;
$$;

-- ---------- 8. Hak akses fungsi (hanya pengguna login) ----------
revoke all on function public.request_admin_action(text, uuid, text, text, text) from public, anon;
revoke all on function public.decide_admin_request(bigint, boolean, text) from public, anon;
revoke all on function public.cancel_admin_request(bigint) from public, anon;
revoke all on function public.admin_edit_user(uuid, text, text, text, text, text, bigint) from public, anon;
revoke all on function public.admin_delete_user(uuid, bigint) from public, anon;
revoke all on function public.admin_reset_password(uuid, text, bigint) from public, anon;
revoke all on function public.clear_admin_log(bigint) from public, anon;
revoke all on function public.pesan_dilihat() from public, anon;
revoke all on function public.tandai_pesan_dibaca() from public, anon;
revoke all on function public.pesan_ringkas() from public, anon;
grant execute on function public.request_admin_action(text, uuid, text, text, text) to authenticated;
grant execute on function public.decide_admin_request(bigint, boolean, text) to authenticated;
grant execute on function public.cancel_admin_request(bigint) to authenticated;
grant execute on function public.admin_edit_user(uuid, text, text, text, text, text, bigint) to authenticated;
grant execute on function public.admin_delete_user(uuid, bigint) to authenticated;
grant execute on function public.admin_reset_password(uuid, text, bigint) to authenticated;
grant execute on function public.clear_admin_log(bigint) to authenticated;
grant execute on function public.pesan_dilihat() to authenticated;
grant execute on function public.tandai_pesan_dibaca() to authenticated;
grant execute on function public.pesan_ringkas() to authenticated;
