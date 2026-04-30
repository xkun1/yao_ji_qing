/// 集中管理应用内的硬编码文本（为后续多语言支持做准备）
class AppStrings {
  // 通用/通用按钮
  static const String cancel = "取消";
  static const String confirm = "确定";
  static const String save = "保存";
  static const String delete = "删除";
  static const String edit = "编辑";
  static const String finish = "完成";
  static const String close = "关闭";
  
  // 统计页
  static const String statsTitle = "健康统计";
  static const String statsComplianceCardTitle = "本周遵医嘱率";
  static const String statsComplianceCardSubtitle = "按时服药比例";
  static const String statsComplianceExcellent = "太棒了！继续保持！";
  static const String statsComplianceGood = "还不错，要继续加油！";
  static const String statsComplianceNeedsImprovement = "要注意按时吃药哦！";
  static const String statsTimeDistributionTitle = "各时段服药次数";
  static const String statsRecentHistoryTitle = "近 7 天服药记录";
  static const String statsEmptyHistory = "暂无服药记录";
  static const String statsMorning = "早晨 (05-11)";
  static const String statsNoon = "中午 (11-16)";
  static const String statsEvening = "晚上 (16-21)";
  static const String statsNight = "深夜 (21-05)";
  
  // 模型管理页
  static const String modelManagerTitle = "引擎管理";
  static const String modelManagerSubtitle = "管理本地 AI 与语音引擎";
  static const String modelStatusNotInstalled = "未安装";
  static const String modelStatusDownloading = "下载中";
  static const String modelStatusInstalled = "已安装";
  static const String modelInstallComplete = "安装完成";
  static const String modelRestarting = "正在重启应用以加载新引擎，请稍候...";

  // 聊天室
  static const String chatAiNotReady = "AI 引擎还没准备好，请先完成模型初始化。";
  static const String chatDeviceNotSupported = "当前设备暂时无法稳定运行药师咨询，请稍后重试。";
  static const String chatEngineIncompatible = "当前 iOS 推理引擎与模型不兼容，请在模型管理里重新安装当前设备支持的引擎。";
  static const String chatAiBusy = "本地药师暂时忙不过来，请稍后再试。";
}
