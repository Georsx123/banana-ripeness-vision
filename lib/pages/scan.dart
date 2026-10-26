import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class BoxPainter extends CustomPainter {
  final ScanResult r;
  BoxPainter(this.r);

  @override
  void paint(Canvas canvas, Size size) {
    if (r.imgW <= 0 || r.imgH <= 0) return;
    final sx = size.width / r.imgW;
    final sy = size.height / r.imgH;
    for (final d in r.dets) {
      if (!d.hasBox) continue;
      final k = infoKelas(d.label);
      final rect = Rect.fromLTWH((d.x! - d.w! / 2) * sx, (d.y! - d.h! / 2) * sy, d.w! * sx, d.h! * sy);
      canvas.drawRect(rect, Paint()
        ..color = k.warna
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
      final tp = TextPainter(
        text: TextSpan(
          text: ' ${k.nama} ${(d.conf * 100).toStringAsFixed(0)}% ',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final top = rect.top - tp.height < 0 ? rect.top : rect.top - tp.height;
      canvas.drawRect(Rect.fromLTWH(rect.left, top, tp.width, tp.height), Paint()..color = k.warna);
      tp.paint(canvas, Offset(rect.left, top));
    }
  }

  @override
  bool shouldRepaint(covariant BoxPainter old) => old.r != r;
}

class ResultPanel extends StatelessWidget {
  final ScanResult result;
  const ResultPanel({super.key, required this.result});

  Widget _badge(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12.5)),
      );

  Widget _classCard(ClassSummary g, bool biggest) {
    final k = infoKelas(g.key);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: alpha(k.warna, .85), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: alpha(k.warna, .2), shape: BoxShape.circle, border: Border.all(color: k.warna, width: 3)),
            child: const Text('🍌', style: TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(k.nama, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: kBrown)),
                _badge('\u00d7${g.count}', alpha(k.warna, .22), kBrown),
                if (biggest) _badge('Terbanyak', alpha(kAmber, .3), kBrown),
              ]),
              const SizedBox(height: 2),
              Text('Rata-rata akurasi ${(g.avgConf * 100).toStringAsFixed(1)}%', style: TextStyle(color: Colors.brown.shade400)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: g.avgConf.clamp(0.0, 1.0), minHeight: 10, color: k.warna, backgroundColor: alpha(k.warna, .15)),
        ),
        const SizedBox(height: 12),
        Text(k.deskripsi, style: const TextStyle(height: 1.4, color: kBrown)),
        if (k.saran.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: alpha(kAmber, .15), borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.tips_and_updates_rounded, size: 20, color: kDeepAmber),
              const SizedBox(width: 8),
              Expanded(child: Text(k.saran, style: const TextStyle(height: 1.4))),
            ]),
          ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = result.summary;
    if (groups.isEmpty) {
      return const AppCard(
        child: Row(children: [
          Icon(Icons.search_off_rounded, color: Colors.grey, size: 34),
          SizedBox(width: 12),
          Expanded(child: Text('Tidak ada pisang terdeteksi. Coba dekatkan kamera dan pastikan cahaya cukup.')),
        ]),
      );
    }
    final total = result.dets.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.center_focus_strong_rounded, color: kDeepAmber),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$total pisang terdeteksi \u2022 ${groups.length} kelas',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kBrown)),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final g in groups)
              Chip(
                backgroundColor: alpha(infoKelas(g.key).warna, .2),
                side: BorderSide.none,
                label: Text('${infoKelas(g.key).nama} \u00d7${g.count}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      ResponsiveWrap(minWidth: 400, children: [
        for (var i = 0; i < groups.length; i++) _classCard(groups[i], groups.length > 1 && i == 0),
      ]),
    ]);
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  int _mode = 0; // 0 = gambar, 1 = realtime

  MaintState? _maint = Api.lastMaint; // status mode pemeliharaan (dari cache jika ada)
  bool _limitHit = false; // server menolak karena batas scan harian habis

  // mode gambar
  final _picker = ImagePicker();
  Uint8List? _img;
  ScanResult? _imgResult;
  bool _loading = false; // sedang scan
  bool _savingImg = false;
  bool _savedImg = false;
  String? _error;

  // mode realtime
  CameraController? _cam;
  Timer? _timer;
  bool _camBusy = false;
  bool _starting = false;
  ScanResult? _live;
  String? _liveError;
  bool _saving = false;
  bool _liveSaved = false;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    Api.quota.addListener(_onQuota);
    Api.refreshQuota();
    _checkMaint();
  }

  void _onQuota() {
    if (mounted) setState(() {});
  }

  /// Batas scan harian sudah habis (dari angka sisa scan atau penolakan server).
  bool get _exhausted {
    final q = Api.quota.value;
    return _limitHit || (q != null && q.exhausted);
  }

  /// Matikan kamera dan beri tahu pengguna bahwa batas scan harian habis.
  void _enterLimit(String? msg) {
    _stopLive();
    if (!mounted) return;
    setState(() => _limitHit = true);
    toast(context, msg ?? 'Batas scan hari ini sudah habis. Kamera dimatikan.', error: true);
  }

  Future<void> _checkMaint() async {
    try {
      final m = await Api.maintenance();
      if (!mounted) return;
      setState(() => _maint = m);
      if (m.on) _stopLive();
    } catch (_) {
      // jika gagal membaca pengaturan, anggap scan aktif
      if (mounted && _maint == null) setState(() => _maint = const MaintState(false, MaintState.defaultMessage));
    }
  }

  void _enterMaint(String message) {
    _stopLive();
    if (mounted) setState(() => _maint = MaintState(true, message));
  }

  Widget _maintCard() {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 22),
      child: Column(children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(color: alpha(kAmber, .2), shape: BoxShape.circle),
          child: const Icon(Icons.construction_rounded, size: 40, color: kDeepAmber),
        ),
        const SizedBox(height: 16),
        const Text('Scan sedang dijeda', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kBrown)),
        const SizedBox(height: 8),
        Text(_maint?.message ?? MaintState.defaultMessage,
            textAlign: TextAlign.center, style: TextStyle(color: Colors.brown.shade500, height: 1.4)),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            await _checkMaint();
            if (mounted && _maint?.on != true) toast(context, 'Scan sudah aktif kembali.');
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Cek lagi'),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    Api.quota.removeListener(_onQuota);
    _timer?.cancel();
    _cam?.dispose();
    super.dispose();
  }

  // ---------- mode gambar ----------
  Future<void> _pick(ImageSource s) async {
    try {
      final f = await _picker.pickImage(source: s, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (f == null) return;
      final b = await f.readAsBytes();
      if (!mounted) return;
      setState(() {
        _img = b;
        _imgResult = null;
        _savedImg = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = Api.friendly(e));
    }
  }

  /// Dijalankan hanya saat tombol "Scan Gambar" ditekan.
  Future<void> _scanImage() async {
    final b = _img;
    if (b == null) return;
    if (_exhausted) {
      toast(context, 'Batas scan hari ini sudah habis. Coba lagi besok.', error: true);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _imgResult = null;
      _savedImg = false;
    });
    try {
      final r = await Roboflow.detect(b);
      if (!mounted) return;
      setState(() => _imgResult = r);
    } on LimitException catch (e) {
      _enterLimit(e.message);
    } on MaintenanceException catch (e) {
      _enterMaint(e.message);
    } catch (e) {
      if (mounted) setState(() => _error = Api.friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Dijalankan hanya saat tombol "Simpan ke Riwayat" ditekan.
  Future<void> _saveImage() async {
    final r = _imgResult;
    if (r == null || r.top == null) return;
    setState(() => _savingImg = true);
    try {
      await Api.saveScanResult(mode: 'gambar', result: r);
      if (!mounted) return;
      setState(() => _savedImg = true);
      toast(context, 'Hasil tersimpan ke riwayat');
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _savingImg = false);
    }
  }

  Widget _imageWithBoxes() {
    final r = _imgResult;
    if (r == null || !r.hasBoxes) {
      return ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(_img!, fit: BoxFit.contain));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: r.imgW / r.imgH,
        child: Stack(fit: StackFit.expand, children: [
          Image.memory(_img!, fit: BoxFit.fill),
          CustomPaint(painter: BoxPainter(r)),
        ]),
      ),
    );
  }

  Widget _imageMode() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ResponsiveWrap(minWidth: 220, children: [
        AppButton(label: 'Pilih dari Galeri', icon: Icons.photo_library_rounded, onPressed: _loading ? null : () => _pick(ImageSource.gallery)),
        OutlinedButton.icon(
          onPressed: _loading ? null : () => _pick(ImageSource.camera),
          icon: const Icon(Icons.photo_camera_rounded),
          label: const Text('Ambil Foto'),
        ),
      ]),
      const SizedBox(height: 16),
      if (_img == null)
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
          child: Column(children: [
            Icon(Icons.add_photo_alternate_rounded, size: 60, color: alpha(kAmber, .8)),
            const SizedBox(height: 10),
            const Text('Unggah foto pisang untuk dideteksi', style: TextStyle(fontWeight: FontWeight.w700, color: kBrown)),
            const SizedBox(height: 4),
            Text('Pastikan pisang terlihat jelas dan cahaya cukup.', style: TextStyle(color: Colors.brown.shade400)),
          ]),
        )
      else
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(children: [
              Stack(alignment: Alignment.center, children: [
                _imageWithBoxes(),
                if (_loading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(16)),
                      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
                  ),
              ]),
            ]),
          ),
        ),
      if (_img != null) ...[
        const SizedBox(height: 14),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(children: [
              ResponsiveWrap(minWidth: 240, children: [
                AppButton(
                  label: _imgResult == null ? 'Scan Gambar' : 'Scan Ulang',
                  icon: Icons.document_scanner_rounded,
                  loading: _loading,
                  onPressed: _exhausted ? null : _scanImage,
                ),
                if (_imgResult != null)
                  AppButton(
                    label: _savedImg ? 'Tersimpan ke Riwayat' : 'Simpan ke Riwayat',
                    icon: _savedImg ? Icons.check_circle_rounded : Icons.save_rounded,
                    loading: _savingImg,
                    onPressed: (_imgResult?.top == null || _savedImg) ? null : _saveImage,
                  ),
              ]),
              const SizedBox(height: 8),
              Text(
                _imgResult == null
                    ? 'Periksa gambar di atas, lalu tekan "Scan Gambar" untuk mendeteksi.'
                    : (_savedImg ? 'Hasil sudah masuk ke menu Riwayat.' : 'Hasil belum disimpan. Tekan "Simpan ke Riwayat" jika sudah sesuai.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.brown.shade400, fontSize: 12.5),
              ),
            ]),
          ),
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: 14),
        AppCard(color: Colors.red.shade50, child: Text(_error!, style: TextStyle(color: Colors.red.shade800))),
      ],
      if (_imgResult != null) ...[
        const SizedBox(height: 16),
        Reveal(key: ObjectKey(_imgResult), child: ResultPanel(result: _imgResult!)),
      ],
    ]);
  }

  // ---------- mode realtime ----------
  Future<void> _startLive() async {
    if (_exhausted) {
      toast(context, 'Batas scan hari ini sudah habis. Coba lagi besok.', error: true);
      return;
    }
    setState(() {
      _starting = true;
      _liveError = null;
      _live = null;
      _paused = false;
      _liveSaved = false;
    });
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw Exception('Kamera tidak ditemukan.');
      final cd = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(cd, ResolutionPreset.medium, enableAudio: false);
      await c.initialize();
      try {
        await c.setFlashMode(FlashMode.off); // cegah lampu kilat menyala tiap pengambilan gambar
      } catch (_) {
        // sebagian perangkat/browser tidak mendukung pengaturan flash
      }
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _cam = c);
      _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _tick());
    } catch (e) {
      if (mounted) {
        setState(() => _liveError = 'Kamera tidak bisa diakses. Pastikan izin kamera diaktifkan di browser. ($e)');
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _tick() async {
    final c = _cam;
    if (_paused || _camBusy || c == null || !c.value.isInitialized) return;
    if (_exhausted) {
      _enterLimit(null);
      return;
    }
    _camBusy = true;
    try {
      final x = await c.takePicture();
      final b = await x.readAsBytes();
      final r = await Roboflow.detect(b);
      if (mounted) {
        setState(() {
          if (!_paused) {
            _live = r;
            _liveSaved = false;
          }
          _liveError = null;
        });
        if (_exhausted) _enterLimit(null);
      }
    } on LimitException catch (e) {
      _enterLimit(e.message);
    } on MaintenanceException catch (e) {
      _enterMaint(e.message);
    } catch (e) {
      if (mounted) setState(() => _liveError = Api.friendly(e));
    } finally {
      _camBusy = false;
    }
  }

  Future<void> _stopLive() async {
    _timer?.cancel();
    _timer = null;
    final c = _cam;
    if (mounted) setState(() => _cam = null);
    await c?.dispose();
  }

  Future<void> _saveLive() async {
    final r = _live;
    if (r == null || r.top == null) return;
    setState(() => _saving = true);
    try {
      await Api.saveScanResult(mode: 'realtime', result: r);
      if (mounted) {
        setState(() => _liveSaved = true);
        toast(context, 'Hasil tersimpan ke riwayat');
      }
    } catch (e) {
      if (mounted) toast(context, Api.friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _liveMode() {
    final c = _cam;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (c == null)
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(children: [
            Icon(Icons.videocam_rounded, size: 60, color: alpha(kAmber, .8)),
            const SizedBox(height: 10),
            const Text('Deteksi langsung lewat kamera', style: TextStyle(fontWeight: FontWeight.w700, color: kBrown)),
            const SizedBox(height: 4),
            Text('Browser akan meminta izin kamera. Pilih "Izinkan".', textAlign: TextAlign.center, style: TextStyle(color: Colors.brown.shade400)),
            const SizedBox(height: 18),
            SizedBox(width: 260, child: AppButton(label: 'Aktifkan Kamera', icon: Icons.play_arrow_rounded, loading: _starting, onPressed: _exhausted ? null : _startLive)),
          ]),
        )
      else ...[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio,
                child: Stack(fit: StackFit.expand, children: [
                  CameraPreview(c),
                  if (_live != null && _live!.hasBoxes) CustomPaint(painter: BoxPainter(_live!)),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _paused ? Colors.orange.shade700 : Colors.red.shade600, borderRadius: BorderRadius.circular(20)),
                      child: Text(_paused ? 'HASIL DIJEDA' : 'LIVE', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ResponsiveWrap(minWidth: 220, children: [
          AppButton(
            label: _liveSaved ? 'Tersimpan ke Riwayat' : 'Simpan ke Riwayat',
            icon: _liveSaved ? Icons.check_circle_rounded : Icons.save_rounded,
            loading: _saving,
            onPressed: (_live?.top == null || _liveSaved) ? null : _saveLive,
          ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _paused = !_paused),
            icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            label: Text(_paused ? 'Lanjutkan Deteksi' : 'Jeda Hasil'),
          ),
          OutlinedButton.icon(onPressed: _stopLive, icon: const Icon(Icons.stop_rounded), label: const Text('Matikan Kamera')),
        ]),
        const SizedBox(height: 8),
        Text(
          'Arahkan kamera ke pisang. Tekan "Jeda Hasil" untuk menahan hasil, lalu "Simpan ke Riwayat" jika sudah sesuai.',
          style: TextStyle(color: Colors.brown.shade400, fontSize: 12.5),
        ),
      ],
      if (_liveError != null) ...[
        const SizedBox(height: 14),
        AppCard(color: Colors.red.shade50, child: Text(_liveError!, style: TextStyle(color: Colors.red.shade800))),
      ],
      if (c == null && _live?.top != null) ...[
        const SizedBox(height: 14),
        AppButton(
          label: _liveSaved ? 'Tersimpan ke Riwayat' : 'Simpan hasil terakhir ke Riwayat',
          icon: _liveSaved ? Icons.check_circle_rounded : Icons.save_rounded,
          loading: _saving,
          onPressed: _liveSaved ? null : _saveLive,
        ),
      ],
      if (_live != null) ...[
        const SizedBox(height: 16),
        ResultPanel(result: _live!),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_maint == null) {
      // Status belum diketahui: jangan tampilkan menu scan dulu supaya tidak berkedip.
      return PageWrap(
        title: 'Scan Pisang',
        subtitle: 'Memeriksa status layanan...',
        children: const [
          Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    if (_maint?.on == true) {
      return PageWrap(
        title: 'Scan Pisang',
        subtitle: 'Deteksi tingkat kematangan pisang.',
        children: [_maintCard()],
      );
    }
    return PageWrap(
      title: 'Scan Pisang',
      subtitle: 'Pilih mode deteksi: unggah gambar atau kamera realtime.',
      children: [
        const QuotaBar(),
        const SizedBox(height: 14),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, icon: Icon(Icons.image_rounded), label: Text('Input Gambar')),
            ButtonSegment(value: 1, icon: Icon(Icons.videocam_rounded), label: Text('Realtime')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) {
            if (_mode == 1 && s.first == 0) _stopLive();
            setState(() => _mode = s.first);
          },
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, if (current != null) current],
          ),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(_mode), child: _mode == 0 ? _imageMode() : _liveMode()),
        ),
      ],
    );
  }
}
