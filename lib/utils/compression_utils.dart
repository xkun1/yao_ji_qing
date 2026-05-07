import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'dart:convert';

import '../core/exceptions.dart';

/// 压缩工具类
class CompressionUtils {
  CompressionUtils._internal();

  static final CompressionUtils _instance = CompressionUtils._internal();

  factory CompressionUtils() => _instance;

  /// 解压 tar.gz 文件
  static Future<void> extractTarGz(
    File archiveFile,
    Directory outputDir, {
    bool stripFirstPathComponent = false,
  }) async {
    if (!await archiveFile.exists()) {
      throw FileSystemException.notFound(path: archiveFile.path);
    }
    await outputDir.create(recursive: true);

    final reader = _ByteStreamReader(
      gzip.decoder.bind(archiveFile.openRead()),
    );
    while (true) {
      final header = await reader.readExactly(512);
      if (header == null || _isEmptyTarBlock(header)) break;

      final name = _readTarName(header);
      final size = _readTarSize(header);
      final typeFlag = header[156];
      if (name.isEmpty) {
        await reader.skip(size + _tarPaddingSize(size));
        continue;
      }

      final outputPath = _safeTarOutputPath(
        outputDir,
        name,
        stripFirstPathComponent: stripFirstPathComponent,
      );
      final isDirectory = typeFlag == 53; // '5'
      if (isDirectory) {
        if (outputPath != null) {
          await Directory(outputPath).create(recursive: true);
        }
      } else if (outputPath != null) {
        final outputFile = File(outputPath);
        await outputFile.parent.create(recursive: true);
        final sink = outputFile.openWrite();
        try {
          await reader.pipeBytes(size, sink);
        } finally {
          await sink.close();
        }
      } else {
        await reader.skip(size);
      }

      await reader.skip(_tarPaddingSize(size));
    }
  }

  /// 检查是否为空的 tar 块
  static bool _isEmptyTarBlock(Uint8List block) {
    for (final byte in block) {
      if (byte != 0) return false;
    }
    return true;
  }

  /// 读取 tar 名称
  static String _readTarName(Uint8List header) {
    final name = _readNullTerminatedAscii(header, 0, 100);
    final prefix = _readNullTerminatedAscii(header, 345, 155);
    return prefix.isEmpty ? name : '$prefix/$name';
  }

  /// 读取 null 终止的 ASCII 字符串
  static String _readNullTerminatedAscii(
      Uint8List bytes, int start, int length) {
    var end = start;
    final maxEnd = start + length;
    while (end < maxEnd && bytes[end] != 0) {
      end++;
    }
    return ascii.decode(bytes.sublist(start, end)).trim();
  }

  /// 读取 tar 大小
  static int _readTarSize(Uint8List header) {
    final value = _readNullTerminatedAscii(header, 124, 12).trim();
    if (value.isEmpty) return 0;
    return int.parse(value, radix: 8);
  }

  /// 计算 tar 填充大小
  static int _tarPaddingSize(int fileSize) {
    final remainder = fileSize % 512;
    return remainder == 0 ? 0 : 512 - remainder;
  }

  /// 生成安全的 tar 输出路径
  static String? _safeTarOutputPath(
    Directory outputDir,
    String tarPath, {
    required bool stripFirstPathComponent,
  }) {
    final segments = tarPath
        .replaceAll('\\', '/')
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (stripFirstPathComponent && segments.isNotEmpty) {
      segments.removeAt(0);
    }
    if (segments.isEmpty ||
        segments.any((segment) => segment == '.' || segment == '..')) {
      return null;
    }
    return '${outputDir.path}/${segments.join('/')}';
  }
}

/// 字节流读取器
class _ByteStreamReader {
  _ByteStreamReader(Stream<List<int>> stream)
      : _iterator = StreamIterator(stream);

  final StreamIterator<List<int>> _iterator;
  Uint8List _buffer = Uint8List(0);
  int _offset = 0;
  bool _isDone = false;

  Future<Uint8List?> readExactly(int byteCount) async {
    if (byteCount == 0) return Uint8List(0);

    var remaining = byteCount;
    final output = BytesBuilder(copy: false);
    while (remaining > 0) {
      if (!await _ensureBuffer()) {
        if (output.isEmpty) return null;
        throw FileSystemException.readFailed();
      }

      final available = _buffer.length - _offset;
      final take = remaining < available ? remaining : available;
      output.add(Uint8List.sublistView(_buffer, _offset, _offset + take));
      _offset += take;
      remaining -= take;
    }
    return output.takeBytes();
  }

  Future<void> pipeBytes(int byteCount, IOSink sink) async {
    var remaining = byteCount;
    while (remaining > 0) {
      if (!await _ensureBuffer()) {
        throw FileSystemException.readFailed();
      }

      final available = _buffer.length - _offset;
      final take = remaining < available ? remaining : available;
      sink.add(Uint8List.sublistView(_buffer, _offset, _offset + take));
      _offset += take;
      remaining -= take;
    }
  }

  Future<void> skip(int byteCount) async {
    var remaining = byteCount;
    while (remaining > 0) {
      if (!await _ensureBuffer()) {
        throw FileSystemException.readFailed();
      }

      final available = _buffer.length - _offset;
      final take = remaining < available ? remaining : available;
      _offset += take;
      remaining -= take;
    }
  }

  Future<bool> _ensureBuffer() async {
    while (_offset >= _buffer.length) {
      if (_isDone) return false;
      if (!await _iterator.moveNext()) {
        _isDone = true;
        return false;
      }
      _buffer = Uint8List.fromList(_iterator.current);
      _offset = 0;
    }
    return true;
  }
}
