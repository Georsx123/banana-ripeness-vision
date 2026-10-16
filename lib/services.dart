import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'theme.dart';

SupabaseClient get sb => Supabase.instance.client;

class Profile {
  final String id, nama, username, email, noTelp, gender, role, plan;
  final DateTime? createdAt;
  Profile({
    required this.id,
    required this.nama,
    required this.username,
    required this.email,
    required this.noTelp,
    required this.gender,
    required this.role,
    required this.plan,
    this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        nama: (m['nama'] ?? '') as String,
        username: (m['username'] ?? '') as String,
        email: (m['email'] ?? '') as String,
        noTelp: (m['no_telp'] ?? '') as String,
        gender: (m['jenis_kelamin'] ?? '') as String,
        role: (m['role'] ?? 'user') as String,
        plan: (m['plan'] ?? 'reguler') as String,
        createdAt: m['created_at'] == null ? null : DateTime.tryParse(m['created_at'] as String)?.toLocal(),
      );

  bool get isAdmin => role == 'admin';

  /// Email asli (bukan alamat internal buatan aplikasi versi lama).
  bool get hasRealEmail => email.isNotEmpty && !email.endsWith('@${AppConfig.emailDomain}');
}

class AppState {
  static final ValueNotifier<Profile?> notifier = ValueNotifier<Profile?>(null);
  static Profile? get me => notifier.value;
  static set me(Profile? p) => notifier.value = p;

  /// Bernilai true tepat setelah login: tampilkan jendela penawaran paket sekali.
  static bool showOffer = false;
}

/// Sisa scan harian pengguna (admin: tanpa batas).
class Quota {
  final String plan;
  final bool unlimited;
  final int used, limit;
  const Quota(this.plan, this.unlimited, this.used, this.limit);
  int get remaining => unlimited ? 0 : (limit - used < 0 ? 0 : limit - used);
  bool get exhausted => !unlimited && remaining <= 0;
  factory Quota.fromMap(Map m) => Quota(
        '${m['plan'] ?? 'reguler'}',
        m['unlimited'] == true,
        (m['used'] as num?)?.toInt() ?? 0,
        (m['limit'] as num?)?.toInt() ?? 0,
      );
}

class LimitException implements Exception {
  final String message;
  LimitException(this.message);
  @override
  String toString() => message;
}

/// Status mode pemeliharaan (saat aktif, fitur scan dimatikan).
class MaintState {
  final bool on;
  final String message;
  const MaintState(this.on, this.message);
  static const defaultMessage = 'Fitur scan sedang istirahat sementara. Silakan coba lagi nanti.';
}

class MaintenanceException implements Exception {
  final String message;
  MaintenanceException(this.message);
  @override
  String toString() => message;
}

class EmailNotVerified implements Exception {
  final String email;
  EmailNotVerified(this.email);
  @override
  String toString() => 'Email belum diverifikasi. Cek inbox atau folder spam.';
}

class Detection {
  final String label;
  final double conf; // 0..1
  final double? x, y, w, h;
  Detection({required this.label, required this.conf, this.x, this.y, this.w, this.h});
  bool get hasBox => x != null && y != null && w != null && h != null;
}

class ClassSummary {
  final String key;
  final int count;
  final double avgConf; // 0..1
  ClassSummary(this.key, this.count, this.avgConf);
}

class ScanResult {
  final List<Detection> dets;
  final double imgW, imgH;
  ScanResult(this.dets, this.imgW, this.imgH);
  Detection? get top => dets.isEmpty ? null : dets.first;

  /// Ringkasan per kelas: jumlah pisang dan rata-rata akurasi, urut dari yang terbanyak.
  List<ClassSummary> get summary {
    final cnt = <String, int>{};
    final sum = <String, double>{};
    for (final d in dets) {
      final k = infoKelas(d.label).key;
      cnt[k] = (cnt[k] ?? 0) + 1;
      sum[k] = (sum[k] ?? 0) + d.conf;
    }
    final list = <ClassSummary>[
      for (final e in cnt.entries) ClassSummary(e.key, e.value, sum[e.key]! / e.value),
    ];
    list.sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : b.avgConf.compareTo(a.avgConf);
    });
    return list;
  }
  bool get hasBoxes => imgW > 0 && imgH > 0 && dets.any((d) => d.hasBox);
}

class Api {
  // ---------------- AUTH ----------------
  static String emailFor(String username) => '${username.trim().toLowerCase()}@${AppConfig.emailDomain}';

  static String friendly(Object e) {
    if (e is AuthException) {
      final m = e.message.toLowerCase();
      if (m.contains('failed to fetch') || m.contains('clientexception') || m.contains('socketexception')) {
        return 'Tidak bisa terhubung ke server Supabase. Periksa internet, lalu coba lagi.';
      }
      if (m.contains('invalid login')) return 'Username/email atau password salah.';
      if (m.contains('already registered') || m.contains('already been registered')) {
        return 'Email sudah terdaftar. Silakan masuk.';
      }
      if (m.contains('not confirmed')) return 'Email belum diverifikasi. Cek inbox atau folder spam.';
      if (m.contains('only request this after')) return 'Tunggu sekitar 1 menit sebelum meminta kode lagi.';
      if (m.contains('rate limit')) return 'Batas pengiriman email tercapai. Coba lagi beberapa saat lagi.';
      if (m.contains('expired') || (m.contains('token') && m.contains('invalid'))) {
        return 'Kode OTP salah atau sudah kedaluwarsa.';
      }
      if (m.contains('different from the old') || m.contains('same as the old')) {
        return 'Password baru harus berbeda dari password lama.';
      }
      if (m.contains('reauthentication')) return 'Kode OTP diperlukan. Kirim kode ke email dulu.';
      if (m.contains('database error')) return 'Data tidak valid atau username sudah dipakai.';
      return e.message;
    }
    if (e is PostgrestException) return e.message;
    final s = e.toString();
    if (e is http.ClientException || s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'Gagal terhubung ke internet / server.';
    }
    return s.replaceFirst('Exception: ', '');
  }

  static Future<Profile?> loadProfile() async {
    final u = sb.auth.currentUser;
    if (u == null) return null;
    final m = await sb.from('profiles').select().eq('id', u.id).maybeSingle();
    if (m == null) return null;
    AppState.me = Profile.fromMap(m);
    return AppState.me;
  }

  /// Login dengan username ATAU email.
  static Future<void> login(String identifier, String password) async {
    final id = identifier.trim();
    String email;
    if (id.contains('@')) {
      email = id.toLowerCase();
    } else {
      try {
        final r = await sb.rpc('login_email', params: {'p_username': id});
        email = (r is String && r.isNotEmpty) ? r : emailFor(id);
      } catch (_) {
        email = emailFor(id); // SQL tambahan belum dijalankan: pakai cara lama
      }
    }
    try {
      await sb.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('not confirmed')) throw EmailNotVerified(email);
      rethrow;
    }
    final p = await loadProfile();
    if (p == null) {
      await sb.auth.signOut();
      throw Exception('Profil tidak ditemukan. Hubungi admin.');
    }
  }

  // ---- Registrasi: 1) verifikasi email dengan OTP, 2) lengkapi data ----
  /// Langkah 1: kirim kode OTP ke email. Akun belum lengkap sampai langkah 2 selesai.
  static Future<void> sendRegisterOtp(String email) async {
    final e = email.trim().toLowerCase();
    try {
      final taken = await sb.rpc('email_registered', params: {'p_email': e});
      if (taken == true) throw Exception('Email sudah terdaftar. Silakan masuk, atau pakai Lupa password.');
    } on PostgrestException {
      // SQL tambahan belum dijalankan: lewati pengecekan awal
    }
    await sb.auth.signInWithOtp(email: e, shouldCreateUser: true);
  }

  static Future<void> verifyRegisterOtp(String email, String code) async {
    final e = email.trim().toLowerCase();
    try {
      await sb.auth.verifyOTP(email: e, token: code.trim(), type: OtpType.email);
    } on AuthException {
      await sb.auth.verifyOTP(email: e, token: code.trim(), type: OtpType.signup);
    }
  }

  /// Langkah 2: setelah email terverifikasi, simpan password dan data akun.
  static Future<void> completeRegistration({
    required String nama,
    required String username,
    required String noTelp,
    required String gender,
    required String password,
  }) async {
    final u = sb.auth.currentUser;
    if (u == null) throw Exception('Sesi verifikasi berakhir. Ulangi dari awal.');
    try {
      final ok = await sb.rpc('username_available', params: {'p_username': username.trim()});
      if (ok == false) throw Exception('Username sudah dipakai, pilih yang lain.');
    } on PostgrestException {
      // SQL tambahan belum dijalankan: lewati pengecekan awal
    }
    await sb.auth.updateUser(UserAttributes(password: password));
    try {
      await sb.from('profiles').update({
        'nama': nama.trim(),
        'username': username.trim().toLowerCase(),
        'no_telp': noTelp.trim(),
        'jenis_kelamin': gender,
        'profil_lengkap': true,
      }).eq('id', u.id);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw Exception('Username sudah dipakai, pilih yang lain.');
      rethrow;
    }
    await sb.auth.signOut();
    AppState.me = null;
  }

  static Future<void> resendSignupEmail(String email) async {
    await sb.auth.resend(type: OtpType.signup, email: email.trim().toLowerCase());
  }

  // ---- Kuota scan harian ----
  static final ValueNotifier<Quota?> quota = ValueNotifier<Quota?>(null);

  static Future<void> refreshQuota() async {
    try {
      final r = await sb.rpc('my_quota');
      if (r is Map) quota.value = Quota.fromMap(r);
    } catch (_) {
      // abaikan: tampilan menunggu data berikutnya
    }
  }

  // ---- Lupa password lewat OTP email ----
  /// Mencari email akun dari username/email yang diketik di halaman login. null jika tidak ada.
  static Future<String?> accountEmail(String identifier) async {
    final r = await sb.rpc('account_email', params: {'p_identifier': identifier.trim()});
    return (r is String && r.isNotEmpty) ? r : null;
  }

  static Future<void> sendResetOtp(String email) => sb.auth.resetPasswordForEmail(email.trim().toLowerCase());

  static Future<void> verifyResetOtp(String email, String code) async {
    await sb.auth.verifyOTP(email: email.trim().toLowerCase(), token: code.trim(), type: OtpType.recovery);
  }

  /// Dipanggil setelah kode OTP benar: simpan password baru lalu keluar (harus masuk lagi).
  static Future<void> finishReset(String newPass) async {
    await sb.auth.updateUser(UserAttributes(password: newPass));
    await sb.auth.signOut();
    AppState.me = null;
  }

  // ---- Ganti password di Profil dengan OTP email ----
  static Future<void> sendProfileOtp() => sb.auth.reauthenticate();

  static Future<void> changePasswordWithOtp(String code, String newPass) async {
    await sb.auth.updateUser(UserAttributes(password: newPass, nonce: code.trim()));
  }

  static Future<void> logout() async {
    await sb.auth.signOut();
    AppState.me = null;
    quota.value = null;
  }

  static Future<void> updateMyProfile({required String nama, required String noTelp, required String gender}) async {
    final id = sb.auth.currentUser!.id;
    await sb.from('profiles').update({'nama': nama.trim(), 'no_telp': noTelp.trim(), 'jenis_kelamin': gender}).eq('id', id);
    await loadProfile();
  }

  // ---------------- RIWAYAT ----------------
  static Future<List<Map<String, dynamic>>> myScans() async {
    final r = await sb
        .from('riwayat_scan')
        .select()
        .eq('user_id', sb.auth.currentUser!.id)
        .order('created_at', ascending: false)
        .limit(500);
    return List<Map<String, dynamic>>.from(r);
  }

  static Future<void> saveScan({
    required String mode,
    required String kelas,
    required double akurasi,
    required int jumlah,
  }) async {
    await sb.from('riwayat_scan').insert({
      'user_id': sb.auth.currentUser!.id,
      'mode': mode,
      'kelas': kelas,
      'akurasi': double.parse(akurasi.toStringAsFixed(2)),
      'jumlah_objek': jumlah,
    });
  }

  /// Menyimpan SEMUA kelas hasil scan: satu baris per kelas (dengan jumlah pisang & rata-rata akurasi).
  /// Semua baris dari satu scan memakai waktu (created_at) yang sama.
  static Future<void> saveScanResult({required String mode, required ScanResult result}) async {
    final uid = sb.auth.currentUser!.id;
    final rows = <Map<String, dynamic>>[
      for (final g in result.summary)
        {
          'user_id': uid,
          'mode': mode,
          'kelas': g.key,
          'akurasi': double.parse((g.avgConf * 100).toStringAsFixed(2)),
          'jumlah_objek': g.count,
        },
    ];
    if (rows.isEmpty) return;
    await sb.from('riwayat_scan').insert(rows);
  }

  static Future<void> deleteScan(int id) async {
    await sb.from('riwayat_scan').delete().eq('id', id);
  }

  static Future<void> clearMyScans() async {
    await sb.from('riwayat_scan').delete().eq('user_id', sb.auth.currentUser!.id);
  }

  // ---------------- PEMELIHARAAN ----------------
  /// Status pemeliharaan terakhir yang diketahui (dipakai agar halaman Scan langsung benar).
  static MaintState? lastMaint;

  static Future<MaintState> maintenance() async {
    final r = await sb.from('app_settings').select();
    final m = <String, String>{
      for (final e in List<Map<String, dynamic>>.from(r)) '${e['key']}': '${e['value']}',
    };
    final msg = (m['maintenance_message'] ?? '').trim();
    final st = MaintState(m['maintenance'] == 'on', msg.isEmpty ? MaintState.defaultMessage : msg);
    lastMaint = st;
    return st;
  }

  static Future<void> setMaintenance(bool on, String message) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await sb.from('app_settings').upsert([
      {'key': 'maintenance', 'value': on ? 'on' : 'off', 'updated_at': now},
      {'key': 'maintenance_message', 'value': message.trim(), 'updated_at': now},
    ]);
    lastMaint = MaintState(on, message.trim().isEmpty ? MaintState.defaultMessage : message.trim());
    await logAdmin(on ? 'Nonaktifkan scan (mode pemeliharaan ON)' : 'Aktifkan scan (mode pemeliharaan OFF)', message.trim());
  }

  // ---------------- ADMIN ----------------
  static Future<List<Profile>> allUsers() async {
    final r = await sb.from('profiles').select().eq('profil_lengkap', true).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(r).map(Profile.fromMap).toList();
  }

  // ---- Aksi sensitif admin: butuh izin yang disetujui admin lain (dicek juga di database) ----
  static Future<void> adminEditUser(
    String id, {
    required int izin,
    required String nama,
    required String noTelp,
    required String gender,
    required String role,
    required String plan,
  }) async {
    await sb.rpc('admin_edit_user', params: {
      'p_id': id,
      'p_nama': nama.trim(),
      'p_no_telp': noTelp.trim(),
      'p_gender': gender,
      'p_role': role,
      'p_plan': plan,
      'p_request': izin,
    });
  }

  static Future<void> adminDeleteUser(String id, {required int izin}) async {
    await sb.rpc('admin_delete_user', params: {'p_id': id, 'p_request': izin});
  }

  static Future<void> adminResetPassword(String id, String newPass, {required int izin}) async {
    await sb.rpc('admin_reset_password', params: {'p_id': id, 'p_new_password': newPass, 'p_request': izin});
  }

  static Future<void> clearAdminLogs({required int izin}) async {
    await sb.rpc('clear_admin_log', params: {'p_request': izin});
  }

  // ---- Permintaan izin antar admin ----
  static Future<int?> myGrant(String jenis, String? targetId) async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return null;
    final since = DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String();
    var q = sb.from('admin_request').select('id').eq('dibuat_oleh', uid).eq('jenis', jenis).eq('status', 'disetujui').gte('diputus_pada', since);
    if (targetId != null) q = q.eq('target_id', targetId);
    final r = await q.order('diputus_pada', ascending: false).limit(1);
    final list = List<Map<String, dynamic>>.from(r);
    return list.isEmpty ? null : (list.first['id'] as num).toInt();
  }

  static Future<bool> myPending(String jenis, String? targetId) async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return false;
    var q = sb.from('admin_request').select('id').eq('dibuat_oleh', uid).eq('jenis', jenis).eq('status', 'menunggu');
    if (targetId != null) q = q.eq('target_id', targetId);
    final r = await q.limit(1);
    return List<Map<String, dynamic>>.from(r).isNotEmpty;
  }

  static Future<void> requestAction({
    required String jenis,
    String? targetId,
    required String label,
    required String detail,
    required String alasan,
  }) async {
    await sb.rpc('request_admin_action', params: {
      'p_jenis': jenis,
      'p_target': targetId,
      'p_label': label,
      'p_detail': detail,
      'p_alasan': alasan.trim(),
    });
  }

  static Future<void> decideRequest(int id, bool setuju, String catatan) async {
    await sb.rpc('decide_admin_request', params: {'p_id': id, 'p_setuju': setuju, 'p_catatan': catatan.trim()});
  }

  static Future<void> cancelRequest(int id) async {
    await sb.rpc('cancel_admin_request', params: {'p_id': id});
  }

  static Future<List<Map<String, dynamic>>> adminRequests() async {
    final r = await sb.from('admin_request').select().order('created_at', ascending: false).limit(500);
    return List<Map<String, dynamic>>.from(r);
  }

  // ---- Notifikasi menu Pesan ----
  static final ValueNotifier<bool> pesanDot = ValueNotifier<bool>(false);

  static Future<Map<String, int>> refreshPesanSummary() async {
    try {
      final r = await sb.rpc('pesan_ringkas');
      if (r is Map) {
        final m = <String, int>{for (final e in r.entries) '${e.key}': (e.value as num).toInt()};
        pesanDot.value = (m['baru'] ?? 0) + (m['perlu_tindakan'] ?? 0) > 0;
        return m;
      }
    } catch (_) {
      // abaikan
    }
    return <String, int>{};
  }

  static Future<DateTime> pesanDilihat() async {
    final r = await sb.rpc('pesan_dilihat');
    return DateTime.tryParse('$r')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static Future<void> tandaiPesanDibaca() async {
    try {
      await sb.rpc('tandai_pesan_dibaca');
    } catch (_) {
      // abaikan
    }
    await refreshPesanSummary();
  }

  // ---- Riwayat aktivitas admin ----
  /// Mencatat aktivitas admin. Kegagalan mencatat tidak menggagalkan aksinya.
  static Future<void> logAdmin(String aksi, String detail) async {
    try {
      final uid = sb.auth.currentUser?.id;
      if (uid == null) return;
      await sb.from('admin_log').insert({
        'admin_id': uid,
        'admin_nama': AppState.me?.nama ?? '',
        'aksi': aksi,
        'detail': detail,
      });
    } catch (_) {
      // abaikan
    }
  }

  static Future<List<Map<String, dynamic>>> adminLogs() async {
    final r = await sb.from('admin_log').select().order('created_at', ascending: false).limit(1000);
    return List<Map<String, dynamic>>.from(r);
  }

  // ---- Pesan (catatan) admin ----
  static String _ringkas(String s) {
    final t = s.trim().replaceAll('\n', ' ');
    return t.length > 120 ? '${t.substring(0, 120)}\u2026' : t;
  }

  static Future<List<Map<String, dynamic>>> adminPesan() async {
    final r = await sb.from('admin_pesan').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  static Future<void> addPesan(String isi) async {
    await sb.from('admin_pesan').insert({
      'isi': isi.trim(),
      'dibuat_oleh': sb.auth.currentUser!.id,
      'dibuat_nama': AppState.me?.nama ?? '',
    });
    await logAdmin('Tambah pesan', _ringkas(isi));
  }

  static Future<void> deletePesan(int id, String isi, String alasan) async {
    await sb.from('admin_pesan').delete().eq('id', id);
    await logAdmin('Hapus pesan', 'Alasan: $alasan. Pesan: ${_ringkas(isi)}');
  }

  // ---- Riwayat scan semua pengguna (khusus admin) ----
  /// Maksimal 5000 catatan terbaru (diambil per 1000), lengkap dengan nama pengguna.
  static Future<List<Map<String, dynamic>>> allScans() async {
    final out = <Map<String, dynamic>>[];
    for (var from = 0; from < 5000; from += 1000) {
      final r = await sb
          .from('riwayat_scan')
          .select('id, user_id, mode, kelas, akurasi, jumlah_objek, created_at, profiles(nama, username)')
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(from, from + 999);
      final list = List<Map<String, dynamic>>.from(r);
      out.addAll(list);
      if (list.length < 1000) break;
    }
    return out;
  }

  static Future<Map<String, dynamic>> adminStats() async {
    final r = await sb.rpc('admin_stats');
    return Map<String, dynamic>.from(r as Map);
  }
}

class Roboflow {
  /// Gambar dikirim ke Edge Function Supabase bernama "scan".
  /// Private API key Roboflow disimpan sebagai Secret di Supabase, bukan di aplikasi.
  static Future<ScanResult> detect(Uint8List bytes) async {
    final dynamic raw;
    try {
      final res = await sb.functions
          .invoke('scan', body: {'image': base64Encode(bytes)})
          .timeout(const Duration(seconds: 40));
      raw = res.data;
    } on TimeoutException {
      throw Exception('Server terlalu lama merespons. Coba lagi.');
    } on FunctionException catch (e) {
      if (e.status == 503) {
        var msg = MaintState.defaultMessage;
        final d = e.details;
        if (d is Map && d['message'] != null) msg = '${d['message']}';
        throw MaintenanceException(msg);
      }
      if (e.status == 429) {
        var msg = 'Batas scan harian sudah habis. Coba lagi besok.';
        final d = e.details;
        if (d is Map && d['message'] != null) msg = '${d['message']}';
        Api.refreshQuota();
        throw LimitException(msg);
      }
      throw Exception('Fungsi scan gagal (${e.status}): ${e.details}');
    } catch (e) {
      throw Exception('Tidak bisa menghubungi fungsi "scan" di Supabase. Pastikan sudah di-deploy. Detail: $e');
    }
    final dynamic j = raw is String ? jsonDecode(raw) : raw;
    if (j is! Map) throw Exception('Respons dari server tidak dikenali.');
    final m = Map<String, dynamic>.from(j);
    final qm = m['_quota'];
    if (qm is Map) Api.quota.value = Quota.fromMap(qm);

    double? num_(dynamic v) => v is num ? v.toDouble() : null;
    final dets = <Detection>[];
    final p = m['predictions'];
    if (p is List) {
      for (final e in p) {
        if (e is Map) {
          dets.add(Detection(
            label: '${e['class'] ?? e['class_name'] ?? ''}',
            conf: num_(e['confidence']) ?? 0,
            x: num_(e['x']),
            y: num_(e['y']),
            w: num_(e['width']),
            h: num_(e['height']),
          ));
        }
      }
    } else if (p is Map) {
      p.forEach((k, v) {
        if (v is Map) dets.add(Detection(label: '$k', conf: num_(v['confidence']) ?? 0));
      });
    }
    dets.sort((a, b) => b.conf.compareTo(a.conf));
    double iw = 0, ih = 0;
    final img = m['image'];
    if (img is Map) {
      iw = num_(img['width']) ?? 0;
      ih = num_(img['height']) ?? 0;
    }
    return ScanResult(dets, iw, ih);
  }
}

/// Banyak scan unik (baris dengan created_at sama dihitung satu scan).
int distinctScans(Iterable<Map<String, dynamic>> rows) => rows.map((s) => '${s['created_at']}').toSet().length;

/// Jumlah pisang per kelas (menjumlahkan jumlah_objek).
Map<String, int> classCounts(Iterable<Map<String, dynamic>> rows) {
  final m = <String, int>{};
  for (final s in rows) {
    final k = infoKelas('${s['kelas']}').key;
    final n = (s['jumlah_objek'] as num?)?.toInt() ?? 1;
    m[k] = (m[k] ?? 0) + n;
  }
  return m;
}
