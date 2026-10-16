import 'dart:convert';
import 'dart:typed_data';

/// Pembuat berkas Excel (.xlsx) sederhana tanpa paket tambahan.
/// Nilai sel yang didukung: String (teks), int/double (angka), DateTime (tanggal-jam), null (kosong).
/// Angka dan tanggal disimpan sebagai angka/tanggal sungguhan, jadi tidak tergantung pengaturan
/// wilayah (koma/titik) di komputer pengguna.
const String xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

const String _contentTypes = r'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>''';

const String _rootRels = r'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>''';

const String _workbookRels = r'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>''';

// Indeks gaya (cellXfs): 0 teks biasa, 1 judul kolom, 2 tanggal-jam, 3 angka 1 desimal, 4 rata tengah
const String _styles = r'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="2"><numFmt numFmtId="164" formatCode="dd/mm/yyyy\ hh:mm"/><numFmt numFmtId="165" formatCode="0.0"/></numFmts><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFFE082"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border><border><left style="thin"><color rgb="FFBDBDBD"/></left><right style="thin"><color rgb="FFBDBDBD"/></right><top style="thin"><color rgb="FFBDBDBD"/></top><bottom style="thin"><color rgb="FFBDBDBD"/></bottom><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="5"><xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/><xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf><xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf><xf numFmtId="165" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf><xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>''';

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _col(int i) {
  var s = '';
  var n = i;
  do {
    s = String.fromCharCode(65 + n % 26) + s;
    n = n ~/ 26 - 1;
  } while (n >= 0);
  return s;
}

double _serial(DateTime d) {
  final l = d.toLocal();
  final utc = DateTime.utc(l.year, l.month, l.day, l.hour, l.minute, l.second);
  return utc.difference(DateTime.utc(1899, 12, 30)).inSeconds / 86400.0;
}

String _sheetXml(List<String> headers, List<List<Object?>> rows, List<double> widths, List<int> centerCols) {
  final b = StringBuffer();
  b.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
  b.write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
  b.write('<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>');
  b.write('<sheetFormatPr defaultRowHeight="15"/>');
  b.write('<cols>');
  for (var i = 0; i < headers.length; i++) {
    final w = i < widths.length ? widths[i] : 16.0;
    b.write('<col min="${i + 1}" max="${i + 1}" width="$w" customWidth="1"/>');
  }
  b.write('</cols><sheetData>');
  b.write('<row r="1" ht="24" customHeight="1">');
  for (var c = 0; c < headers.length; c++) {
    b.write('<c r="${_col(c)}1" s="1" t="inlineStr"><is><t>${_esc(headers[c])}</t></is></c>');
  }
  b.write('</row>');
  for (var r = 0; r < rows.length; r++) {
    final rn = r + 2;
    b.write('<row r="$rn">');
    for (var c = 0; c < headers.length; c++) {
      final v = c < rows[r].length ? rows[r][c] : null;
      final ref = '${_col(c)}$rn';
      final center = centerCols.contains(c);
      if (v == null) {
        b.write('<c r="$ref" s="${center ? 4 : 0}"/>');
      } else if (v is DateTime) {
        b.write('<c r="$ref" s="2"><v>${_serial(v)}</v></c>');
      } else if (v is int) {
        b.write('<c r="$ref" s="${center ? 4 : 0}"><v>$v</v></c>');
      } else if (v is double) {
        b.write('<c r="$ref" s="3"><v>$v</v></c>');
      } else {
        b.write('<c r="$ref" s="${center ? 4 : 0}" t="inlineStr"><is><t>${_esc('$v')}</t></is></c>');
      }
    }
    b.write('</row>');
  }
  b.write('</sheetData>');
  b.write('<autoFilter ref="A1:${_col(headers.length - 1)}${rows.length + 1}"/>');
  b.write('</worksheet>');
  return b.toString();
}

final List<int> _crcTable = () {
  final t = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
    }
    t[n] = c & 0xFFFFFFFF;
  }
  return t;
}();

int _crc32(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c = (_crcTable[(c ^ b) & 0xFF] ^ (c >> 8)) & 0xFFFFFFFF;
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

void _u16(BytesBuilder b, int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);
void _u32(BytesBuilder b, int v) => b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);

/// Membuat berkas ZIP tanpa kompresi (metode "store").
Uint8List _zipStore(Map<String, List<int>> files) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  var offset = 0;
  files.forEach((name, data) {
    final nameBytes = utf8.encode(name);
    final crc = _crc32(data);
    _u32(out, 0x04034b50);
    _u16(out, 20);
    _u16(out, 0x0800);
    _u16(out, 0);
    _u16(out, 0);
    _u16(out, 0x21);
    _u32(out, crc);
    _u32(out, data.length);
    _u32(out, data.length);
    _u16(out, nameBytes.length);
    _u16(out, 0);
    out.add(nameBytes);
    out.add(data);

    _u32(central, 0x02014b50);
    _u16(central, 20);
    _u16(central, 20);
    _u16(central, 0x0800);
    _u16(central, 0);
    _u16(central, 0);
    _u16(central, 0x21);
    _u32(central, crc);
    _u32(central, data.length);
    _u32(central, data.length);
    _u16(central, nameBytes.length);
    _u16(central, 0);
    _u16(central, 0);
    _u16(central, 0);
    _u16(central, 0);
    _u32(central, 0);
    _u32(central, offset);
    central.add(nameBytes);

    offset += 30 + nameBytes.length + data.length;
  });
  final cd = central.toBytes();
  final cdOffset = out.length;
  out.add(cd);
  _u32(out, 0x06054b50);
  _u16(out, 0);
  _u16(out, 0);
  _u16(out, files.length);
  _u16(out, files.length);
  _u32(out, cd.length);
  _u32(out, cdOffset);
  _u16(out, 0);
  return out.toBytes();
}

/// Membuat isi berkas .xlsx dengan satu lembar kerja.
/// [centerCols] = indeks kolom (mulai 0) yang isinya rata tengah.
Uint8List buildXlsx({
  required String sheetName,
  required List<String> headers,
  required List<List<Object?>> rows,
  List<double> widths = const [],
  List<int> centerCols = const [],
}) {
  final workbook = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="${_esc(sheetName)}" sheetId="1" r:id="rId1"/></sheets></workbook>';
  return _zipStore({
    '[Content_Types].xml': utf8.encode(_contentTypes),
    '_rels/.rels': utf8.encode(_rootRels),
    'xl/workbook.xml': utf8.encode(workbook),
    'xl/_rels/workbook.xml.rels': utf8.encode(_workbookRels),
    'xl/styles.xml': utf8.encode(_styles),
    'xl/worksheets/sheet1.xml': utf8.encode(_sheetXml(headers, rows, widths, centerCols)),
  });
}
