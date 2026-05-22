import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @finish.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get finish;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @statsTitle.
  ///
  /// In zh, this message translates to:
  /// **'健康统计'**
  String get statsTitle;

  /// No description provided for @statsComplianceCardTitle.
  ///
  /// In zh, this message translates to:
  /// **'本周遵医嘱率'**
  String get statsComplianceCardTitle;

  /// No description provided for @statsComplianceCardSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按时服药比例'**
  String get statsComplianceCardSubtitle;

  /// No description provided for @statsComplianceExcellent.
  ///
  /// In zh, this message translates to:
  /// **'太棒了！继续保持！'**
  String get statsComplianceExcellent;

  /// No description provided for @statsComplianceGood.
  ///
  /// In zh, this message translates to:
  /// **'还不错，要继续加油！'**
  String get statsComplianceGood;

  /// No description provided for @statsComplianceNeedsImprovement.
  ///
  /// In zh, this message translates to:
  /// **'要注意按时吃药哦！'**
  String get statsComplianceNeedsImprovement;

  /// No description provided for @statsTimeDistributionTitle.
  ///
  /// In zh, this message translates to:
  /// **'各时段服药次数'**
  String get statsTimeDistributionTitle;

  /// No description provided for @statsRecentHistoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'近 7 天服药记录'**
  String get statsRecentHistoryTitle;

  /// No description provided for @statsEmptyHistory.
  ///
  /// In zh, this message translates to:
  /// **'暂无服药记录'**
  String get statsEmptyHistory;

  /// No description provided for @statsMorning.
  ///
  /// In zh, this message translates to:
  /// **'早晨 (05-11)'**
  String get statsMorning;

  /// No description provided for @statsNoon.
  ///
  /// In zh, this message translates to:
  /// **'中午 (11-16)'**
  String get statsNoon;

  /// No description provided for @statsEvening.
  ///
  /// In zh, this message translates to:
  /// **'晚上 (16-21)'**
  String get statsEvening;

  /// No description provided for @statsNight.
  ///
  /// In zh, this message translates to:
  /// **'深夜 (21-05)'**
  String get statsNight;

  /// No description provided for @modelManagerTitle.
  ///
  /// In zh, this message translates to:
  /// **'引擎管理'**
  String get modelManagerTitle;

  /// No description provided for @modelManagerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'管理本地 AI 与语音引擎'**
  String get modelManagerSubtitle;

  /// No description provided for @modelStatusNotInstalled.
  ///
  /// In zh, this message translates to:
  /// **'未安装'**
  String get modelStatusNotInstalled;

  /// No description provided for @modelStatusDownloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get modelStatusDownloading;

  /// No description provided for @modelStatusInstalled.
  ///
  /// In zh, this message translates to:
  /// **'已安装'**
  String get modelStatusInstalled;

  /// No description provided for @modelInstallComplete.
  ///
  /// In zh, this message translates to:
  /// **'安装完成'**
  String get modelInstallComplete;

  /// No description provided for @modelRestarting.
  ///
  /// In zh, this message translates to:
  /// **'正在重启应用以加载新引擎，请稍候...'**
  String get modelRestarting;

  /// No description provided for @chatAiNotReady.
  ///
  /// In zh, this message translates to:
  /// **'AI 引擎还没准备好，请先完成模型初始化。'**
  String get chatAiNotReady;

  /// No description provided for @chatDeviceNotSupported.
  ///
  /// In zh, this message translates to:
  /// **'当前设备暂时无法稳定运行药师咨询，请稍后重试。'**
  String get chatDeviceNotSupported;

  /// No description provided for @chatEngineIncompatible.
  ///
  /// In zh, this message translates to:
  /// **'当前 iOS 推理引擎与模型不兼容，请在模型管理里重新安装当前设备支持的引擎。'**
  String get chatEngineIncompatible;

  /// No description provided for @chatAiBusy.
  ///
  /// In zh, this message translates to:
  /// **'本地药师暂时忙不过来，请稍后再试。'**
  String get chatAiBusy;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
