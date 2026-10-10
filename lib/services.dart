import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'theme.dart';

SupabaseClient get sb => Supabase.instance.client;

class Profile {
  final String id, nama, username, noTelp, gender, role;
  final DateTime? createdAt;
  Profile({
    required this.id,
    required this.nama,
    required this.username,
    required this.noTelp,
    required this.gender,
    required this.role,
    this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        nama: (m['nama'] ?? '') as String,
        username: (m['username'] ?? '') as String,
        noTelp: (m['no_telp'] ?? '') as String,
        gender: (m['jenis_kelamin'] ?? '') as String,
        role: (m['role'] ?? 'user') as String,
        createdAt: m['created_at'] == null ? null : DateTime.tryParse(m['created_at'] as String)?.toLocal(),
      );

  bool get isAdmin => role == 'admin';
}

class AppState {
  static final ValueNotifier<Profile?> notifier = ValueNotifier<Profile?>(null);
  static Profile? get me => notifier.value;
  static set me(Profile? p) => notifier.value = p;
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
      if (m.contains('invalid login')) return 'Username atau password salah.';
      if (m.contains('already registered') || m.contains('already been registered')) {
        return 'Username sudah dipakai, pilih yang lain.';
      }
      if (m.contains('not confirmed')) {
        return 'Akun belum aktif. Matikan "Confirm email" di pengaturan Supabase Auth.';
      }
      if (m.contains('rate limit')) return 'Terlalu banyak percobaan, coba lagi nanti.';
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

  static Future<void> login(String username, String password) async {
    await sb.auth.signInWithPassword(email: emailFor(username), password: password);
    final p = await loadProfile();
    if (p == null) {
      await sb.auth.signOut();
      throw Exception('Profil tidak ditemukan. Hubungi admin.');
    }
  }

  static Future<void> register({
    required String nama,
    required String username,
    required String noTelp,
    required String gender,
    required String password,
  }) async {
    final res = await sb.auth.signUp(
      email: emailFor(username),
      password: password,
      data: {
        'nama': nama.trim(),
        'username': username.trim().toLowerCase(),
        'no_telp': noTelp.trim(),
        'jenis_kelamin': gender,
      },
    );
    if (res.session == null) {
      throw Exception('Registrasi belum aktif. Matikan "Confirm email" di Supabase (Authentication > Sign In / Providers > Email).');
    }
    await sb.auth.signOut();
  }

  static Future<void> logout() async {
    await sb.auth.signOut();
    AppState.me = null;
  }

  static Future<bool> resetPasswordByPhone(String username, String phone, String newPass) async {
    final r = await sb.rpc('reset_password_by_phone', params: {
      'p_username': username.trim(),
      'p_phone': phone.trim(),
      'p_new_password': newPass,
    });
    return r == true;
  }

  static Future<void> changeMyPassword(String newPass) async {
    await sb.auth.updateUser(UserAttributes(password: newPass));
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

  // ---------------- INFO PISANG ----------------
  static Future<List<Map<String, dynamic>>> infoAktif() async {
    final r = await sb.from('info_pisang').select().eq('aktif', true).order('id');
    return List<Map<String, dynamic>>.from(r);
  }

  static Future<List<Map<String, dynamic>>> infoSemua() async {
    final r = await sb.from('info_pisang').select().order('id');
    return List<Map<String, dynamic>>.from(r);
  }

  static Future<void> saveInfo(Map<String, dynamic> data, {int? id}) async {
    if (id == null) {
      await sb.from('info_pisang').insert(data);
    } else {
      await sb.from('info_pisang').update(data).eq('id', id);
    }
  }

  static Future<void> deleteInfo(int id) async {
    await sb.from('info_pisang').delete().eq('id', id);
  }

  // ---------------- ADMIN ----------------
  static Future<List<Profile>> allUsers() async {
    final r = await sb.from('profiles').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(r).map(Profile.fromMap).toList();
  }

  static Future<void> adminCreateUser({
    required String nama,
    required String username,
    required String noTelp,
    required String gender,
    required String password,
    required String role,
  }) async {
    // Memakai klien terpisah (tanpa penyimpanan sesi) agar sesi admin tidak tertimpa.
    final tmp = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit, autoRefreshToken: false),
    );
    try {
      final res = await tmp.auth.signUp(
        email: emailFor(username),
        password: password,
        data: {
          'nama': nama.trim(),
          'username': username.trim().toLowerCase(),
          'no_telp': noTelp.trim(),
          'jenis_kelamin': gender,
        },
      );
      final uid = res.user?.id;
      if (uid == null) throw Exception('Gagal membuat pengguna.');
      if (role == 'admin') {
        await sb.from('profiles').update({'role': 'admin'}).eq('id', uid);
      }
    } finally {
      await tmp.dispose();
    }
  }

  static Future<void> adminUpdateUser(String id, {required String nama, required String noTelp, required String gender, required String role}) async {
    await sb.from('profiles').update({'nama': nama.trim(), 'no_telp': noTelp.trim(), 'jenis_kelamin': gender, 'role': role}).eq('id', id);
  }

  static Future<void> adminDeleteUser(String id) async {
    await sb.rpc('admin_delete_user', params: {'p_id': id});
  }

  static Future<void> adminResetPassword(String id, String newPass) async {
    await sb.rpc('admin_reset_password', params: {'p_id': id, 'p_new_password': newPass});
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
      throw Exception('Fungsi scan gagal (${e.status}): ${e.details}');
    } catch (e) {
      throw Exception('Tidak bisa menghubungi fungsi "scan" di Supabase. Pastikan sudah di-deploy. Detail: $e');
    }
    final dynamic j = raw is String ? jsonDecode(raw) : raw;
    if (j is! Map) throw Exception('Respons dari server tidak dikenali.');
    final m = Map<String, dynamic>.from(j);

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
