// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get finish => '完成';

  @override
  String get close => '关闭';

  @override
  String get statsTitle => '健康统计';

  @override
  String get statsComplianceCardTitle => '本周遵医嘱率';

  @override
  String get statsComplianceCardSubtitle => '按时服药比例';

  @override
  String get statsComplianceExcellent => '太棒了！继续保持！';

  @override
  String get statsComplianceGood => '还不错，要继续加油！';

  @override
  String get statsComplianceNeedsImprovement => '要注意按时吃药哦！';

  @override
  String get statsTimeDistributionTitle => '各时段服药次数';

  @override
  String get statsRecentHistoryTitle => '近 7 天服药记录';

  @override
  String get statsEmptyHistory => '暂无服药记录';

  @override
  String get statsMorning => '早晨 (05-11)';

  @override
  String get statsNoon => '中午 (11-16)';

  @override
  String get statsEvening => '晚上 (16-21)';

  @override
  String get statsNight => '深夜 (21-05)';

  @override
  String get modelManagerTitle => '引擎管理';

  @override
  String get modelManagerSubtitle => '管理本地 AI 与语音引擎';

  @override
  String get modelStatusNotInstalled => '未安装';

  @override
  String get modelStatusDownloading => '下载中';

  @override
  String get modelStatusInstalled => '已安装';

  @override
  String get modelInstallComplete => '安装完成';

  @override
  String get modelRestarting => '正在重启应用以加载新引擎，请稍候...';

  @override
  String get chatAiNotReady => 'AI 引擎还没准备好，请先完成模型初始化。';

  @override
  String get chatDeviceNotSupported => '当前设备暂时无法稳定运行药师咨询，请稍后重试。';

  @override
  String get chatEngineIncompatible =>
      '当前 iOS 推理引擎与模型不兼容，请在模型管理里重新安装当前设备支持的引擎。';

  @override
  String get chatAiBusy => '本地药师暂时忙不过来，请稍后再试。';
}
