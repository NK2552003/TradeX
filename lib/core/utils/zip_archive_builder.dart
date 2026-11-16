import 'dart:convert';
import 'dart:typed_data';

/// Minimal pure-Dart PKZIP (STORE, method 0, UTF-8 filenames) archive builder
/// with standard IEEE 802.3 CRC-32 checksums so GDPR account exports open
/// cleanly in macOS Archive Utility, Windows Explorer, Python zipfile, and unzip.
class ZipArchiveBuilder {
  ZipArchiveBuilder();

  final List<_ZipEntry> _entries = <_ZipEntry>[];

  static final List<int> _crcTable = List<int>.generate(256, (int n) {
    int c = n;
    for (int k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
    }
    return c;
  }, growable: false);

  static int crc32(List<int> bytes) {
    int c = 0xffffffff;
    for (final b in bytes) {
      c = _crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
    }
    return (c ^ 0xffffffff) & 0xffffffff;
  }

  void addString(String path, String content) {
    addBytes(path, Uint8List.fromList(utf8.encode(content)));
  }

  void addJson(String path, Object? data) {
    const encoder = JsonEncoder.withIndent('  ');
    addString(path, '${encoder.convert(data)}\n');
  }

  void addBytes(String path, Uint8List bytes) {
    final normalized = path.replaceAll('\\', '/').replaceFirst(RegExp('^/+'), '');
    final nameBytes = Uint8List.fromList(utf8.encode(normalized));
    _entries.add(
      _ZipEntry(
        nameBytes: nameBytes,
        dataBytes: bytes,
        crc: crc32(bytes),
      ),
    );
  }

  Uint8List build({DateTime? timestamp}) {
    final now = (timestamp ?? DateTime.now()).toLocal();
    final dosTime = _encodeDosTime(now);
    final dosDate = _encodeDosDate(now);

    final builder = BytesBuilder(copy: false);
    final centralDir = BytesBuilder(copy: false);
    int offset = 0;

    for (final entry in _entries) {
      final int localOffset = offset;
      final Uint8List localHeader = _buildLocalFileHeader(
        entry: entry,
        dosTime: dosTime,
        dosDate: dosDate,
      );
      builder.add(localHeader);
      builder.add(entry.dataBytes);
      offset += localHeader.length + entry.dataBytes.length;

      final Uint8List centralHeader = _buildCentralDirectoryHeader(
        entry: entry,
        dosTime: dosTime,
        dosDate: dosDate,
        localHeaderOffset: localOffset,
      );
      centralDir.add(centralHeader);
    }

    final Uint8List cdBytes = centralDir.takeBytes();
    final int cdOffset = offset;
    builder.add(cdBytes);
    builder.add(
      _buildEndOfCentralDirectory(
        entryCount: _entries.length,
        centralDirectorySize: cdBytes.length,
        centralDirectoryOffset: cdOffset,
      ),
    );
    return builder.takeBytes();
  }

  static Uint8List _buildLocalFileHeader({
    required _ZipEntry entry,
    required int dosTime,
    required int dosDate,
  }) {
    final data = ByteData(30);
    data.setUint32(0, 0x04034b50, Endian.little);
    data.setUint16(4, 20, Endian.little); // version needed: 2.0
    data.setUint16(6, 0x0800, Endian.little); // UTF-8 filename flag
    data.setUint16(8, 0, Endian.little); // compression: STORE
    data.setUint16(10, dosTime, Endian.little);
    data.setUint16(12, dosDate, Endian.little);
    data.setUint32(14, entry.crc, Endian.little);
    data.setUint32(18, entry.dataBytes.length, Endian.little);
    data.setUint32(22, entry.dataBytes.length, Endian.little);
    data.setUint16(26, entry.nameBytes.length, Endian.little);
    data.setUint16(28, 0, Endian.little); // extra length
    final out = BytesBuilder(copy: false)
      ..add(data.buffer.asUint8List())
      ..add(entry.nameBytes);
    return out.takeBytes();
  }

  static Uint8List _buildCentralDirectoryHeader({
    required _ZipEntry entry,
    required int dosTime,
    required int dosDate,
    required int localHeaderOffset,
  }) {
    final data = ByteData(46);
    data.setUint32(0, 0x02014b50, Endian.little);
    data.setUint16(4, 20, Endian.little); // version made by
    data.setUint16(6, 20, Endian.little); // version needed
    data.setUint16(8, 0x0800, Endian.little); // UTF-8 filename flag
    data.setUint16(10, 0, Endian.little); // compression: STORE
    data.setUint16(12, dosTime, Endian.little);
    data.setUint16(14, dosDate, Endian.little);
    data.setUint32(16, entry.crc, Endian.little);
    data.setUint32(20, entry.dataBytes.length, Endian.little);
    data.setUint32(24, entry.dataBytes.length, Endian.little);
    data.setUint16(28, entry.nameBytes.length, Endian.little);
    data.setUint16(30, 0, Endian.little); // extra length
    data.setUint16(32, 0, Endian.little); // comment length
    data.setUint16(34, 0, Endian.little); // disk number start
    data.setUint16(36, 0, Endian.little); // internal attrs
    data.setUint32(38, 0, Endian.little); // external attrs
    data.setUint32(42, localHeaderOffset, Endian.little);
    final out = BytesBuilder(copy: false)
      ..add(data.buffer.asUint8List())
      ..add(entry.nameBytes);
    return out.takeBytes();
  }

  static Uint8List _buildEndOfCentralDirectory({
    required int entryCount,
    required int centralDirectorySize,
    required int centralDirectoryOffset,
  }) {
    final data = ByteData(22);
    data.setUint32(0, 0x06054b50, Endian.little);
    data.setUint16(4, 0, Endian.little);
    data.setUint16(6, 0, Endian.little);
    data.setUint16(8, entryCount, Endian.little);
    data.setUint16(10, entryCount, Endian.little);
    data.setUint32(12, centralDirectorySize, Endian.little);
    data.setUint32(16, centralDirectoryOffset, Endian.little);
    data.setUint16(20, 0, Endian.little);
    return data.buffer.asUint8List();
  }

  static int _encodeDosTime(DateTime dt) {
    final h = dt.hour.clamp(0, 23);
    final m = dt.minute.clamp(0, 59);
    final s = (dt.second ~/ 2).clamp(0, 29);
    return (h << 11) | (m << 5) | s;
  }

  static int _encodeDosDate(DateTime dt) {
    final year = (dt.year - 1980).clamp(0, 127);
    final month = dt.month.clamp(1, 12);
    final day = dt.day.clamp(1, 31);
    return (year << 9) | (month << 5) | day;
  }
}

class _ZipEntry {
  const _ZipEntry({
    required this.nameBytes,
    required this.dataBytes,
    required this.crc,
  });

  final Uint8List nameBytes;
  final Uint8List dataBytes;
  final int crc;
}
