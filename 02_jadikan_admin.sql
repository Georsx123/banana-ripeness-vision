-- =====================================================================
-- JADIKAN SEORANG USER MENJADI ADMIN
-- 1) Daftar dulu akun lewat halaman Registrasi di aplikasi.
-- 2) Ganti 'usernameku' di bawah dengan username akun tersebut.
-- 3) Supabase > SQL Editor > paste > Run.
-- =====================================================================
update public.profiles set role = 'admin' where username = 'usernameku';

-- Cek hasilnya:
select username, nama, role from public.profiles;
