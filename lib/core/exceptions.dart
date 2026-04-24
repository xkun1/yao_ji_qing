import 'package:flutter/foundation.dart';

/// 统一的异常基类
class AppException implements Exception {
  const AppException(
    this.message, {
    this.code,
    this.cause,
    this.stackTrace,
  });

  final String message;
  final String? code;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() =>
      'AppException(code: $code, message: $message, cause: $cause)';

  /// 用户友好的错误消息
  String get userMessage => message;

  /// 是否为可恢复错误
  bool get isRecoverable => false;

  /// 是否需要显示给用户
  bool get shouldShowToUser => true;
}

/// 网络相关异常
class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.code,
    super.cause,
    super.stackTrace,
  });

  factory NetworkException.timeout({Object? cause, StackTrace? stackTrace}) {
    return NetworkException(
      '网络连接超时，请检查网络设置',
      code: 'NETWORK_TIMEOUT',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory NetworkException.noConnection({Object? cause, StackTrace? stackTrace}) {
    return NetworkException(
      '网络连接不可用，请检查网络设置',
      code: 'NO_CONNECTION',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory NetworkException.serverError({
    int? statusCode,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return NetworkException(
      '服务器错误${statusCode != null ? ' ($statusCode)' : ''}，请稍后重试',
      code: 'SERVER_ERROR',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  @override
  bool get isRecoverable => true;
}

/// 模型相关异常
class ModelException extends AppException {
  const ModelException(
    super.message, {
    super.code,
    super.cause,
    super.stackTrace,
  });

  factory ModelException.notReady({Object? cause, StackTrace? stackTrace}) {
    return ModelException(
      'AI 引擎还没准备好，请先完成模型初始化',
      code: 'MODEL_NOT_READY',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory ModelException.notInstalled({Object? cause, StackTrace? stackTrace}) {
    return ModelException(
      '模型未安装，请先下载安装模型',
      code: 'MODEL_NOT_INSTALLED',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory ModelException.incompatible({
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return ModelException(
      '当前设备与模型不兼容，请在模型管理里重新安装',
      code: 'MODEL_INCOMPATIBLE',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory ModelException.loadFailed({
    String? backend,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return ModelException(
      '模型加载失败${backend != null ? ' ($backend)' : ''}，请稍后重试',
      code: 'MODEL_LOAD_FAILED',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  @override
  bool get isRecoverable => true;
}

/// 下载相关异常
class DownloadException extends AppException {
  const DownloadException(
    super.message, {
    super.code,
    super.cause,
    super.stackTrace,
    this.progress = 0.0,
  });

  final double progress;

  factory DownloadException.failed({
    required String modelName,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return DownloadException(
      '$modelName下载失败，请检查网络后重试',
      code: 'DOWNLOAD_FAILED',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory DownloadException.cancelled({
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return DownloadException(
      '下载已取消',
      code: 'DOWNLOAD_CANCELLED',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory DownloadException.noSpace({
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return DownloadException(
      '存储空间不足，请清理后重试',
      code: 'NO_SPACE',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  @override
  bool get isRecoverable => true;
}

/// 数据库相关异常
class DatabaseException extends AppException {
  const DatabaseException(
    super.message, {
    super.code,
    super.cause,
    super.stackTrace,
  });

  factory DatabaseException.queryFailed({
    String? query,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return DatabaseException(
      '数据查询失败${query != null ? ': $query' : ''}',
      code: 'QUERY_FAILED',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory DatabaseException.insertFailed({
    String? entity,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return DatabaseException(
      '数据保存失败${entity != null ? ': $entity' : ''}',
      code: 'INSERT_FAILED',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory DatabaseException.deleteFailed({
    String? entity,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return DatabaseException(
      '数据删除失败${entity != null ? ': $entity' : ''}',
      code: 'DELETE_FAILED',
      cause: cause,
      stackTrace: stackTrace,
    );
  }
}

/// 权限相关异常
class PermissionException extends AppException {
  const PermissionException(
    super.message, {
    super.code,
    super.cause,
    super.stackTrace,
  });

  factory PermissionException.denied({
    String? permission,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return PermissionException(
      '权限被拒绝${permission != null ? ': $permission' : ''}，请在设置中开启',
      code: 'PERMISSION_DENIED',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory PermissionException.permanentlyDenied({
    String? permission,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return PermissionException(
      '权限被永久拒绝${permission != null ? ': $permission' : ''}，请在系统设置中手动开启',
      code: 'PERMISSION_PERMANENTLY_DENIED',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  @override
  bool get isRecoverable => true;
}

/// 文件系统相关异常
class FileSystemException extends AppException {
  const FileSystemException(
    super.message, {
    super.code,
    super.cause,
    super.stackTrace,
    this.path,
  });

  final String? path;

  factory FileSystemException.notFound({
    String? path,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return FileSystemException(
      '文件不存在${path != null ? ': $path' : ''}',
      code: 'FILE_NOT_FOUND',
      cause: cause,
      stackTrace: stackTrace,
      path: path,
    );
  }

  factory FileSystemException.readFailed({
    String? path,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return FileSystemException(
      '文件读取失败${path != null ? ': $path' : ''}',
      code: 'FILE_READ_FAILED',
      cause: cause,
      stackTrace: stackTrace,
      path: path,
    );
  }

  factory FileSystemException.writeFailed({
    String? path,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return FileSystemException(
      '文件写入失败${path != null ? ': $path' : ''}',
      code: 'FILE_WRITE_FAILED',
      cause: cause,
      stackTrace: stackTrace,
      path: path,
    );
  }
}

/// 未知异常包装
class UnknownException extends AppException {
  const UnknownException(
    super.message, {
    super.cause,
    super.stackTrace,
  });

  static UnknownException fromError(Object error, [StackTrace? stackTrace]) {
    return UnknownException(
      '发生未知错误: ${error.toString()}',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  @override
  bool get shouldShowToUser => false;
}

/// 异常转换工具
class ExceptionConverter {
  static AppException convert(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }

    final message = error.toString().toLowerCase();

    // 网络相关
    if (message.contains('timeout') || message.contains('timed out')) {
      return NetworkException.timeout(cause: error, stackTrace: stackTrace);
    }
    if (message.contains('no connection') ||
        message.contains('network') ||
        message.contains('internet')) {
      return NetworkException.noConnection(cause: error, stackTrace: stackTrace);
    }
    if (message.contains('server') || message.contains('5')) {
      return NetworkException.serverError(cause: error, stackTrace: stackTrace);
    }

    // 模型相关
    if (message.contains('not ready') ||
        message.contains('not initialized') ||
        message.contains('no active model')) {
      return ModelException.notReady(cause: error, stackTrace: stackTrace);
    }
    if (message.contains('not installed') || message.contains('not found')) {
      return ModelException.notInstalled(cause: error, stackTrace: stackTrace);
    }
    if (message.contains('incompatible') ||
        message.contains('litertresourcecalculator') ||
        message.contains('validatedgraphconfig')) {
      return ModelException.incompatible(cause: error, stackTrace: stackTrace);
    }
    if (message.contains('gpu') ||
        message.contains('npu') ||
        message.contains('backend') ||
        message.contains('delegate')) {
      return ModelException.loadFailed(cause: error, stackTrace: stackTrace);
    }

    // 权限相关
    if (message.contains('permission') || message.contains('denied')) {
      if (message.contains('permanently')) {
        return PermissionException.permanentlyDenied(
          cause: error,
          stackTrace: stackTrace,
        );
      }
      return PermissionException.denied(cause: error, stackTrace: stackTrace);
    }

    // 文件系统相关
    if (message.contains('file') || message.contains('directory')) {
      if (message.contains('not found') || message.contains('does not exist')) {
        return FileSystemException.notFound(
          cause: error,
          stackTrace: stackTrace,
        );
      }
      if (message.contains('read')) {
        return FileSystemException.readFailed(
          cause: error,
          stackTrace: stackTrace,
        );
      }
      if (message.contains('write')) {
        return FileSystemException.writeFailed(
          cause: error,
          stackTrace: stackTrace,
        );
      }
    }

    // 默认返回未知异常
    return UnknownException.fromError(error, stackTrace);
  }
}