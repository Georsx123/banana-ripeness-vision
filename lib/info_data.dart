import 'package:flutter/material.dart';

/// Isi wawasan di Dashboard dan menu About (tertulis di aplikasi, tidak memakai database).
/// Untuk mengubah isinya, edit daftar di bawah lalu Commit dan Sync Changes (dan buat APK baru bila perlu).

class InfoItem {
  final String judul;
  final String isi;
  const InfoItem(this.judul, this.isi);
}

class InfoGroup {
  final String judul;
  final String ringkas;
  final IconData ikon;
  final Color warna;
  final bool terbuka;
  final List<InfoItem> items;
  const InfoGroup(this.judul, this.ringkas, this.ikon, this.warna, this.items, {this.terbuka = false});
}

/// Detail tambahan tiap kelas kematangan (dipakai di Dashboard).
class KelasDetail {
  final String ciri;
  final String cocok;
  const KelasDetail(this.ciri, this.cocok);
}

const Map<String, KelasDetail> kelasDetail = {
  'unripe': KelasDetail(
    'Kulit hijau pekat, tekstur keras, rasa sepat karena pati masih tinggi.',
    'Keripik, pisang goreng tepung, atau dimatangkan dulu beberapa hari.',
  ),
  'freshunripe': KelasDetail(
    'Kulit hijau kekuningan, masih keras tetapi mulai berubah warna.',
    'Ditunggu matang 2-3 hari, atau untuk olahan yang butuh pisang agak keras.',
  ),
  'freshripe': KelasDetail(
    'Kuning cerah merata, tekstur padat, rasa manis seimbang.',
    'Dimakan langsung, salad buah, atau topping sarapan.',
  ),
  'ripe': KelasDetail(
    'Kuning merata dengan sedikit bintik kecil, daging lembut dan manis.',
    'Dimakan langsung, smoothie, atau pisang goreng.',
  ),
  'overripe': KelasDetail(
    'Banyak bintik cokelat, daging sangat lunak dan sangat manis.',
    'Banana bread, pancake, smoothie, atau dibekukan.',
  ),
  'rotten': KelasDetail(
    'Kulit menghitam, berair atau berjamur, berbau menyengat.',
    'Tidak untuk dikonsumsi. Jadikan kompos.',
  ),
};

/// Wawasan di Dashboard.
const List<InfoGroup> infoGroups = [
  InfoGroup(
    'Fakta unik',
    'Hal-hal menarik yang jarang diketahui tentang pisang',
    Icons.lightbulb_rounded,
    Color(0xFF8E24AA),
    [
      InfoItem('Pisang itu buah berry', 'Secara botani, pisang termasuk buah berry (buah buni), sedangkan stroberi justru bukan.'),
      InfoItem('Pohon pisang bukan pohon', 'Yang disebut batang pisang adalah batang semu dari pelepah daun yang saling membungkus. Pohon pisang termasuk herba raksasa.'),
      InfoItem('Berbuah sekali', 'Satu batang pisang berbuah sekali. Setelah panen, batang itu ditebang dan anakan di sampingnya yang menggantikan.'),
      InfoItem('Si penyebab buah lain cepat matang', 'Pisang matang melepaskan gas etilen yang mempercepat pematangan buah di dekatnya, seperti alpukat dan tomat.'),
      InfoItem('Hampir tanpa biji', 'Pisang yang kita makan sehari-hari hasil budidaya dan hampir tidak berbiji. Bintik hitam kecil di tengah daging adalah sisa bakal biji.'),
      InfoItem('Sedikit radioaktif alami', 'Pisang mengandung kalium-40, isotop radioaktif alami, dalam jumlah sangat kecil dan tidak berbahaya.'),
      InfoItem('Sisir dan jari', 'Satu tandan pisang terdiri dari beberapa sisir, dan satu sisir berisi beberapa jari (buah pisang).'),
      InfoItem('Produsen dan eksportir terbesar', 'Menurut data beberapa tahun terakhir, India adalah produsen pisang terbesar dunia, sedangkan Ekuador eksportir terbesar. Indonesia juga termasuk produsen besar.'),
    ],
    terbuka: true,
  ),
  InfoGroup(
    'Info penting',
    'Yang perlu kamu pahami sebelum memilih dan mengonsumsi pisang',
    Icons.info_rounded,
    Color(0xFF1E88E5),
    [
      InfoItem('Pati berubah jadi gula', 'Saat pisang matang, sebagian besar pati diubah menjadi gula sederhana sehingga rasanya makin manis dan lebih mudah dicerna.'),
      InfoItem('Bintik cokelat tanda sangat matang', 'Bintik cokelat di kulit menandakan pisang sudah sangat matang dan paling manis. Cocok untuk kue dan smoothie.'),
      InfoItem('Waspadai pisang busuk', 'Pisang berjamur, berbau fermentasi, atau berair sebaiknya dibuang dan tidak dikonsumsi.'),
      InfoItem('Pisang hijau bisa terasa berat', 'Pisang yang masih hijau tinggi pati resisten, dan pada sebagian orang bisa terasa begah. Rasanya juga sepat.'),
      InfoItem('Hasil AI adalah perkiraan', 'Cahaya, sudut foto, dan latar dapat mempengaruhi hasil deteksi. Gunakan sebagai panduan, bukan satu-satunya penentu.'),
      InfoItem('Bukan nasihat medis', 'Informasi di aplikasi ini bersifat umum. Penderita diabetes atau gangguan ginjal sebaiknya berkonsultasi soal porsi pisang.'),
    ],
  ),
  InfoGroup(
    'Tips mengolah dan memilih',
    'Cara memperlambat, mempercepat, dan menyelamatkan pisang',
    Icons.tips_and_updates_rounded,
    Color(0xFF2E7D32),
    [
      InfoItem('Perlambat pematangan', 'Bungkus tangkai pisang dengan plastik wrap dan jauhkan dari buah lain agar tidak cepat matang.'),
      InfoItem('Percepat pematangan', 'Masukkan pisang mentah ke kantong kertas bersama apel agar lebih cepat matang.'),
      InfoItem('Selamatkan pisang terlalu matang', 'Kupas lalu bekukan pisang yang terlalu matang untuk smoothie atau banana bread.'),
      InfoItem('Es krim sederhana', 'Pisang matang yang dibekukan lalu diblender menghasilkan tekstur seperti es krim tanpa tambahan susu.'),
      InfoItem('Pilih sesuai rencana makan', 'Kuning cerah untuk dimakan hari ini, kekuningan dengan ujung hijau untuk 2-3 hari lagi.'),
      InfoItem('Manfaatkan kulitnya', 'Kulit pisang bisa dijadikan kompos untuk tanaman.'),
    ],
  ),
  InfoGroup(
    'Sejarah pisang',
    'Dari Asia Tenggara sampai ke seluruh dunia',
    Icons.auto_stories_rounded,
    Color(0xFF6D4C41),
    [
      InfoItem('Asal mula', 'Pisang diperkirakan pertama kali dibudidayakan di kawasan Asia Tenggara dan Papua Nugini. Jejak pertanian pisang di Papua Nugini diperkirakan berusia sekitar 7.000 tahun.'),
      InfoItem('Menyebar lewat pelayaran', 'Lewat jalur pelayaran dan perdagangan, pisang menyebar ke Asia Selatan, Afrika, dan kepulauan Pasifik.'),
      InfoItem('Tiba di Amerika', 'Pisang dibawa pelaut Eropa ke benua Amerika sekitar abad ke-16 dan kemudian menjadi tanaman perkebunan besar di sana.'),
      InfoItem('Dari Gros Michel ke Cavendish', 'Pisang Gros Michel pernah mendominasi perdagangan dunia, lalu digantikan Cavendish setelah penyakit layu Panama merusak kebunnya pada pertengahan abad ke-20.'),
      InfoItem('Asal kata banana', 'Kata banana diduga berasal dari bahasa-bahasa di Afrika Barat.'),
      InfoItem('Pisang di Nusantara', 'Pisang sudah lama menjadi bagian budaya Nusantara: dari makanan sehari-hari seperti kolak dan pisang goreng, sampai daunnya sebagai pembungkus makanan.'),
      InfoItem('Ancaman masa kini', 'Penyakit layu Fusarium (dikenal sebagai TR4) kini mengancam kebun pisang Cavendish di sejumlah negara.'),
    ],
  ),
  InfoGroup(
    'Kandungan gizi',
    'Perkiraan per 100 gram pisang',
    Icons.restaurant_rounded,
    Color(0xFFEF6C00),
    [
      InfoItem('Energi', 'Sekitar 89 kkal.'),
      InfoItem('Karbohidrat', 'Sekitar 23 g, terutama gula alami dan pati.'),
      InfoItem('Serat', 'Sekitar 2,6 g.'),
      InfoItem('Protein dan lemak', 'Protein sekitar 1,1 g dan lemak sekitar 0,3 g.'),
      InfoItem('Kalium', 'Sekitar 358 mg, mineral yang berperan untuk otot dan jantung.'),
      InfoItem('Vitamin dan mineral lain', 'Vitamin B6 sekitar 0,4 mg, vitamin C sekitar 8-9 mg, dan magnesium sekitar 27 mg.'),
      InfoItem('Catatan', 'Angka di atas perkiraan dari data gizi umum. Nilainya bervariasi menurut jenis dan tingkat kematangan.'),
    ],
  ),
  InfoGroup(
    'Jenis pisang di Indonesia',
    'Beberapa jenis yang umum dijumpai',
    Icons.eco_rounded,
    Color(0xFF558B2F),
    [
      InfoItem('Pisang Ambon', 'Daging lembut dan manis, umumnya dimakan langsung.'),
      InfoItem('Pisang Raja', 'Manis dan harum, bisa dimakan langsung atau diolah, misalnya dibakar atau digoreng.'),
      InfoItem('Pisang Kepok', 'Umumnya diolah: digoreng, dikukus, atau direbus.'),
      InfoItem('Pisang Tanduk', 'Berukuran besar dan panjang, biasa digoreng atau dibakar.'),
      InfoItem('Pisang Barangan', 'Harum dan manis, dikenal berasal dari Sumatera Utara.'),
      InfoItem('Pisang Mas', 'Berukuran kecil dan sangat manis.'),
      InfoItem('Pisang Cavendish', 'Jenis yang umum di supermarket dan perdagangan ekspor.'),
      InfoItem('Catatan untuk aplikasi', 'Model AI dilatih dengan kumpulan gambar pisang tertentu, jadi hasil untuk jenis yang jarang bisa kurang akurat.'),
    ],
  ),
  InfoGroup(
    'Penyimpanan',
    'Supaya pisang awet dan tidak cepat rusak',
    Icons.kitchen_rounded,
    Color(0xFF00897B),
    [
      InfoItem('Suhu ruang', 'Simpan pisang mentah dan setengah matang di suhu ruang, jauh dari sinar matahari langsung.'),
      InfoItem('Kulkas untuk yang sudah matang', 'Pisang yang sudah matang boleh masuk kulkas. Kulitnya akan menghitam karena dingin, tetapi dagingnya bisa tetap baik.'),
      InfoItem('Jangan kulkaskan yang masih hijau', 'Pisang yang masih hijau sebaiknya tidak dikulkaskan karena sulit matang secara normal.'),
      InfoItem('Gantung tandan', 'Menggantung tandan membantu mengurangi memar di bagian bawah.'),
      InfoItem('Bekukan', 'Kupas, potong, lalu simpan dalam wadah tertutup di freezer untuk smoothie atau kue.'),
    ],
  ),
  InfoGroup(
    'Mitos dan fakta',
    'Meluruskan anggapan yang sering beredar',
    Icons.psychology_alt_rounded,
    Color(0xFFD81B60),
    [
      InfoItem('Mitos: bintik cokelat berarti tidak sehat', 'Fakta: pisang berbintik tetap aman selama tidak berjamur atau berbau busuk. Rasanya lebih manis dan lebih mudah dicerna.'),
      InfoItem('Mitos: pisang pasti bikin gemuk', 'Fakta: pisang rendah lemak. Berat badan dipengaruhi total kalori harian dan pola hidup secara keseluruhan.'),
      InfoItem('Mitos: pisang di kulkas langsung busuk', 'Fakta: kulitnya menghitam karena suhu dingin, tetapi daging pisang matang bisa tetap baik.'),
      InfoItem('Mitos: pisang hijau berbahaya', 'Fakta: pisang mentah aman dimakan, hanya saja sepat dan pada sebagian orang lebih sulit dicerna.'),
    ],
  ),
  InfoGroup(
    'Tips memotret agar hasil scan akurat',
    'Supaya AI lebih mudah mengenali pisangmu',
    Icons.photo_camera_rounded,
    Color(0xFF3949AB),
    [
      InfoItem('Cahaya cukup', 'Gunakan cahaya yang terang dan merata. Hindari bayangan tebal dan cahaya dari belakang pisang.'),
      InfoItem('Latar polos', 'Pakai latar polos seperti kain putih atau meja kosong. Hindari latar berwarna kuning atau cokelat yang mirip pisang.'),
      InfoItem('Jarak yang pas', 'Pisang sebaiknya mengisi sebagian besar bingkai, tidak terlalu jauh dan tidak terpotong.'),
      InfoItem('Jangan menumpuk', 'Pisahkan jari pisang supaya tidak saling menutupi. Satu foto boleh berisi banyak pisang.'),
      InfoItem('Tahan stabil', 'Pegang HP stabil dan tunggu fokus sebelum mengambil foto.'),
      InfoItem('Mode realtime', 'Gerakkan kamera pelan-pelan. Hasil muncul beberapa saat setelah kamera diam.'),
    ],
  ),
];

/// Isi menu About: bagian atas (sebelum daftar kelas).
const List<InfoGroup> aboutAtas = [
  InfoGroup(
    'Tentang aplikasi',
    'Apa itu Banana Ripeness Vision',
    Icons.info_rounded,
    Color(0xFFEF6C00),
    [
      InfoItem('Apa ini?', 'Banana Ripeness Vision adalah aplikasi untuk mengenali tingkat kematangan pisang dari foto atau kamera memakai kecerdasan buatan (AI).'),
      InfoItem('Untuk siapa?', 'Untuk siapa saja yang ingin memilih, menyimpan, atau mengolah pisang dengan tepat: pembeli, pedagang, petani, dan pelajar.'),
      InfoItem('Hasil yang diberikan', 'Setiap hasil menampilkan kelas kematangan, tingkat keyakinan AI, penjelasan ciri, dan saran penanganan.'),
    ],
    terbuka: true,
  ),
  InfoGroup(
    'Manfaat aplikasi',
    'Apa yang bisa kamu lakukan dengan aplikasi ini',
    Icons.volunteer_activism_rounded,
    Color(0xFF2E7D32),
    [
      InfoItem('Memilih pisang saat berbelanja', 'Tahu mana pisang yang siap dimakan, perlu menunggu, atau sebaiknya dihindari.'),
      InfoItem('Membantu pedagang dan petani', 'Memilah pisang berdasarkan tingkat kematangan untuk menentukan waktu jual dan kualitas.'),
      InfoItem('Mengurangi sampah makanan', 'Saran penanganan untuk pisang yang terlalu matang agar tidak terbuang percuma.'),
      InfoItem('Belajar dan edukasi', 'Wawasan seputar pisang lengkap dengan grafik dan fakta menarik di Dashboard.'),
      InfoItem('Memantau riwayat', 'Hasil scan tersimpan di Riwayat, lengkap dengan grafik dan bisa diekspor ke Excel.'),
    ],
  ),
  InfoGroup(
    'Cara menggunakan',
    'Langkah singkat dari scan sampai riwayat',
    Icons.menu_book_rounded,
    Color(0xFF1E88E5),
    [
      InfoItem('1. Buka menu Scan', 'Pilih mode Input Gambar atau Realtime.'),
      InfoItem('2. Siapkan pisang', 'Pilih foto dari galeri atau ambil foto baru. Untuk realtime, aktifkan kamera dan arahkan ke pisang.'),
      InfoItem('3. Mulai deteksi', 'Mode gambar: tekan Scan Gambar. Mode realtime: hasil muncul otomatis, dan kamu bisa menekan Jeda Hasil untuk menahannya.'),
      InfoItem('4. Lihat hasil', 'Kelas, jumlah pisang, akurasi, dan saran penanganan ditampilkan per kelas.'),
      InfoItem('5. Simpan', 'Tekan Simpan ke Riwayat bila hasilnya sesuai.'),
      InfoItem('6. Tinjau', 'Buka Riwayat untuk tabel dan grafik, lalu ekspor ke Excel bila perlu.'),
    ],
  ),
  InfoGroup(
    'Model AI: RF-DETR',
    'Apa itu RF-DETR dan kenapa bukan CNN',
    Icons.psychology_rounded,
    Color(0xFF8E24AA),
    [
      InfoItem('Apa itu RF-DETR?', 'RF-DETR adalah model deteksi objek buatan Roboflow (nama singkat dari Roboflow Detection Transformer). Model ini tidak hanya menebak satu kelas untuk seluruh gambar, tetapi menemukan tiap pisang beserta posisinya dan kelas kematangannya.'),
      InfoItem('Berbasis Transformer (ViT), bukan CNN', 'RF-DETR memakai Vision Transformer (ViT) sebagai tulang punggungnya, dengan bobot awal DINOv2. Berbeda dengan CNN (Convolutional Neural Network) yang memindai gambar lewat filter kecil yang bergeser, Transformer memakai mekanisme perhatian (attention) untuk melihat hubungan antar bagian gambar sekaligus.'),
      InfoItem('Bedanya dengan YOLO', 'YOLO yang populer termasuk keluarga CNN. RF-DETR termasuk keluarga DETR yang memprediksi objek secara langsung, umumnya tanpa langkah pembersihan kotak ganda (NMS) sesudahnya.'),
      InfoItem('Cara kerja singkat', 'Gambar dikirim ke server, model menentukan lokasi dan kelas tiap pisang beserta tingkat keyakinannya, lalu aplikasi merangkum hasilnya per kelas.'),
      InfoItem('Pelatihan', 'Model dilatih ulang dengan kumpulan gambar pisang yang diberi label untuk enam kelas kematangan.'),
      InfoItem('Batasan', 'Akurasi dipengaruhi cahaya, sudut, latar, dan jenis pisang di luar data latih. Hasilnya perkiraan, bukan pengganti penilaian langsung.'),
    ],
  ),
];

/// Isi menu About: bagian bawah (sesudah daftar kelas).
const List<InfoGroup> aboutBawah = [
  InfoGroup(
    'Paket dan batas scan',
    'Reguler, VIP, dan Premium',
    Icons.workspace_premium_rounded,
    Color(0xFFF9A825),
    [
      InfoItem('Batas per hari', 'Reguler 10 scan, VIP 50 scan, Premium 100 scan per hari. Akun admin tanpa batas.'),
      InfoItem('Cara menghitung', 'Setiap hasil yang berhasil diterima dihitung 1 scan, termasuk di mode realtime.'),
      InfoItem('Pengaturan ulang', 'Batas harian diatur ulang setiap pukul 00.00 WIB.'),
      InfoItem('Mengubah paket', 'Untuk saat ini perubahan paket dilakukan oleh admin. Pembelian paket segera hadir.'),
    ],
  ),
  InfoGroup(
    'Privasi dan keamanan data',
    'Data apa yang disimpan dan bagaimana dilindungi',
    Icons.shield_rounded,
    Color(0xFF00897B),
    [
      InfoItem('Data yang disimpan', 'Nama, username, email, nomor telepon, jenis kelamin, paket, dan riwayat hasil scan (kelas, jumlah, akurasi, waktu). Foto tidak disimpan di database aplikasi.'),
      InfoItem('Pengolahan gambar', 'Gambar dikirim lewat server aplikasi ke layanan deteksi (Roboflow) untuk dianalisis. Penyimpanan di sisi layanan itu mengikuti kebijakan penyedianya.'),
      InfoItem('Password', 'Password disimpan terenkripsi dan tidak bisa dilihat siapa pun, termasuk admin. Admin hanya bisa mereset.'),
      InfoItem('Verifikasi email', 'Email diverifikasi dengan kode OTP agar akun valid.'),
      InfoItem('Aksi admin', 'Perubahan data pengguna oleh admin harus disetujui admin lain dan tercatat di riwayat aktivitas.'),
      InfoItem('Hakmu', 'Kamu dapat menghapus riwayat sendiri kapan saja dan mengekspornya ke Excel.'),
    ],
  ),
  InfoGroup(
    'Teknologi yang digunakan',
    'Di balik layar aplikasi ini',
    Icons.memory_rounded,
    Color(0xFF3949AB),
    [
      InfoItem('Flutter', 'Satu kode untuk versi web (PWA) dan Android.'),
      InfoItem('Supabase', 'Database PostgreSQL, login, dan fungsi server.'),
      InfoItem('Roboflow RF-DETR', 'Model deteksi objek berbasis Transformer untuk mengenali kematangan pisang.'),
      InfoItem('Email OTP', 'Kode verifikasi dikirim lewat layanan email.'),
      InfoItem('GitHub Pages', 'Tempat versi web aplikasi di-hosting.'),
    ],
  ),
  InfoGroup(
    'Batasan dan catatan',
    'Hal yang perlu kamu perhatikan',
    Icons.warning_amber_rounded,
    Color(0xFFE65100),
    [
      InfoItem('Hasil adalah perkiraan', 'Jangan jadikan satu-satunya dasar menilai kelayakan konsumsi. Jika ragu, jangan dimakan.'),
      InfoItem('Butuh internet', 'Deteksi, login, dan riwayat memakai server, jadi aplikasi belum bisa dipakai tanpa internet.'),
      InfoItem('Kualitas foto', 'Foto buram, gelap, atau terlalu jauh dapat menurunkan akurasi.'),
      InfoItem('Jenis pisang', 'Jenis pisang yang jarang atau tidak ada di data latih bisa salah dikenali.'),
    ],
  ),
  InfoGroup(
    'Tanya jawab',
    'Pertanyaan yang sering muncul',
    Icons.help_outline_rounded,
    Color(0xFFD81B60),
    [
      InfoItem('Kenapa hasil scan berbeda untuk pisang yang sama?', 'Cahaya, sudut, dan latar berpengaruh. Coba foto ulang dengan cahaya lebih baik.'),
      InfoItem('Kenapa scan saya habis?', 'Ada batas harian sesuai paketmu. Batas diatur ulang pukul 00.00 WIB.'),
      InfoItem('Bagaimana kalau lupa password?', 'Di halaman masuk, isi username atau email lalu tekan Lupa password. Kode OTP dikirim ke emailmu.'),
      InfoItem('Bagaimana menyimpan hasil?', 'Tekan Simpan ke Riwayat setelah scan, lalu lihat di menu Riwayat.'),
      InfoItem('Bisa dipasang seperti aplikasi?', 'Bisa. Lewat menu browser Instal aplikasi, atau lewat berkas APK untuk Android.'),
    ],
  ),
];
