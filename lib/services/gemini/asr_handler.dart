import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';

/// ASR 处理器
class AsrHandler {
  AsrHandler._internal();

  static final AsrHandler _instance = AsrHandler._internal();

  factory AsrHandler() => _instance;

  /// 查找 ASR 模型路径
  Future<String?> findModelPath() async {
    final extDir = Platform.isAndroid ? await getExternalStorageDirectory() : null;
    final intDir = await getApplicationDocumentsDirectory();
    final possiblePaths = <String>[];

    if (extDir != null) {
      possiblePaths.add('${extDir.path}/${AppConstants.asrModelsDirName}/${AppConstants.asrDirName}');
      possiblePaths.add('${extDir.path}/${AppConstants.asrDirName}');
    }
    possiblePaths.add('${intDir.path}/${AppConstants.asrModelsDirName}/${AppConstants.asrDirName}');
    possiblePaths.add('${intDir.path}/${AppConstants.asrDirName}');

    for (final path in possiblePaths) {
      final dir = Directory(path);
      if (await _hasAsrModelFiles(dir)) return path;
    }
    return null;
  }

  /// 检查 ASR 文件是否存在
  Future<bool> checkFilesExist() async {
    return (await findModelPath()) != null;
  }

  /// 检查目录是否包含 ASR 模型文件
  Future<bool> _hasAsrModelFiles(Directory dir) async {
    if (!await dir.exists()) return false;

    var hasTokens = false;
    var hasEncoder = false;
    var hasDecoder = false;

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.path.split(RegExp(r'[/\\]')).last.toLowerCase();
        final size = await entity.length();
        if (name == 'tokens.txt' && size > 0) hasTokens = true;
        if (name.endsWith('.onnx') &&
            name.contains('encoder') &&
            size >= AppConstants.minAsrEncoderBytes) {
          hasEncoder = true;
        }
        if (name.endsWith('.onnx') &&
            name.contains('decoder') &&
            size >= AppConstants.minAsrDecoderBytes) {
          hasDecoder = true;
        }
        if (hasTokens && hasEncoder && hasDecoder) return true;
      }
    } catch (_) {
      return false;
    }

    return false;
  }

  /// 删除 ASR 模型
  Future<void> deleteModel() async {
    final path = await findModelPath();
    if (path != null) {
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  }

  /// 获取 ASR 模型路径用于删除
  Future<String> getModelPathForDeletion() async {
    final path = await findModelPath();
    if (path != null) return path;
    final intDir = await getApplicationDocumentsDirectory();
    return '${intDir.path}/${AppConstants.asrModelsDirName}/${AppConstants.asrDirName}';
  }
}