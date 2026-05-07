import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/exceptions.dart';

/// 文件工具类
class FileUtils {
  FileUtils._internal();

  static final FileUtils _instance = FileUtils._internal();

  factory FileUtils() => _instance;

  /// 获取文件大小（格式化）
  static String formatFileSize(int bytes) {
    if (bytes < AppConstants.bytesPerKB) {
      return '$bytes B';
    } else if (bytes < AppConstants.bytesPerMB) {
      return '${(bytes / AppConstants.bytesPerKB).toStringAsFixed(1)} KB';
    } else if (bytes < AppConstants.bytesPerGB) {
      return '${(bytes / AppConstants.bytesPerMB).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / AppConstants.bytesPerGB).toStringAsFixed(2)} GB';
    }
  }

  /// 获取文件大小
  static Future<String> getFileSize(String path) async {
    final file = File(path);
    if (await file.exists()) {
      final bytes = await file.length();
      return formatFileSize(bytes);
    }
    return '未下载';
  }

  /// 获取目录大小
  static Future<String> getDirSize(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      int totalSize = 0;
      try {
        await for (var file in dir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      } catch (_) {}
      return formatFileSize(totalSize);
    }
    return '未下载';
  }

  /// 删除文件
  static Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 删除目录
  static Future<void> deleteDirectory(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// 检查文件是否存在
  static Future<bool> fileExists(String path) async {
    final file = File(path);
    return await file.exists();
  }

  /// 检查目录是否存在
  static Future<bool> directoryExists(String path) async {
    final dir = Directory(path);
    return await dir.exists();
  }

  /// 创建目录
  static Future<void> createDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// 保存 WAV 文件
  static Future<String> saveWav(
    Float32List samples,
    int sampleRate,
    String fileName,
  ) async {
    final int numSamples = samples.length;
    const int numChannels = 1;
    const int bitsPerSample = 16;
    final int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const int blockAlign = numChannels * bitsPerSample ~/ 8;
    final int dataSize = numSamples * numChannels * bitsPerSample ~/ 8;
    final int fileSize = 36 + dataSize;

    final Uint8List header = Uint8List(44);
    final ByteData bd = ByteData.view(header.buffer);

    bd.setUint8(0, 0x52); // R
    bd.setUint8(1, 0x49); // I
    bd.setUint8(2, 0x46); // F
    bd.setUint8(3, 0x46); // F
    bd.setUint32(4, fileSize, Endian.little);
    bd.setUint8(8, 0x57); // W
    bd.setUint8(9, 0x41); // A
    bd.setUint8(10, 0x56); // V
    bd.setUint8(11, 0x45); // E
    bd.setUint8(12, 0x66); // f
    bd.setUint8(13, 0x6d); // m
    bd.setUint8(14, 0x74); // t
    bd.setUint8(15, 0x20); // space
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, numChannels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, blockAlign, Endian.little);
    bd.setUint16(34, bitsPerSample, Endian.little);
    bd.setUint8(36, 0x64); // d
    bd.setUint8(37, 0x61); // a
    bd.setUint8(38, 0x74); // a
    bd.setUint8(39, 0x61); // a
    bd.setUint32(40, dataSize, Endian.little);

    final Int16List pcmSamples = Int16List(numSamples);
    final ByteData bdSamples = ByteData.view(pcmSamples.buffer);
    for (int i = 0; i < numSamples; i++) {
      double val = samples[i];
      if (val > 1.0) val = 1.0;
      if (val < -1.0) val = -1.0;
      bdSamples.setInt16(i * 2, (val * 32767).toInt(), Endian.little);
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');

    final output = BytesBuilder(copy: false);
    output.add(header);
    output.add(Uint8List.view(pcmSamples.buffer));
    await file.writeAsBytes(output.takeBytes());
    return file.path;
  }

  /// 读取文件为字节
  static Future<Uint8List> readFileAsBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException.notFound(path: path);
    }
    return await file.readAsBytes();
  }

  /// 写入字节到文件
  static Future<void> writeFileAsBytes(String path, Uint8List bytes) async {
    final file = File(path);
    await file.writeAsBytes(bytes);
  }

  /// 复制文件
  static Future<void> copyFile(String sourcePath, String targetPath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException.notFound(path: sourcePath);
    }
    await sourceFile.copy(targetPath);
  }

  /// 移动文件
  static Future<void> moveFile(String sourcePath, String targetPath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException.notFound(path: sourcePath);
    }
    await sourceFile.rename(targetPath);
  }
}
