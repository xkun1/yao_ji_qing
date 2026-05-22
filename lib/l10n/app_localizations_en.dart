// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get finish => 'Finish';

  @override
  String get close => 'Close';

  @override
  String get statsTitle => 'Health Stats';

  @override
  String get statsComplianceCardTitle => 'Weekly Compliance';

  @override
  String get statsComplianceCardSubtitle => 'On-time medication rate';

  @override
  String get statsComplianceExcellent => 'Great job! Keep it up!';

  @override
  String get statsComplianceGood => 'Not bad, keep going!';

  @override
  String get statsComplianceNeedsImprovement =>
      'Remember to take your meds on time!';

  @override
  String get statsTimeDistributionTitle => 'Medication by Time';

  @override
  String get statsRecentHistoryTitle => 'Past 7 Days';

  @override
  String get statsEmptyHistory => 'No records found';

  @override
  String get statsMorning => 'Morning (05-11)';

  @override
  String get statsNoon => 'Noon (11-16)';

  @override
  String get statsEvening => 'Evening (16-21)';

  @override
  String get statsNight => 'Night (21-05)';

  @override
  String get modelManagerTitle => 'Engine Manager';

  @override
  String get modelManagerSubtitle => 'Manage local AI and voice engines';

  @override
  String get modelStatusNotInstalled => 'Not Installed';

  @override
  String get modelStatusDownloading => 'Downloading';

  @override
  String get modelStatusInstalled => 'Installed';

  @override
  String get modelInstallComplete => 'Installation Complete';

  @override
  String get modelRestarting =>
      'Restarting app to load new engine, please wait...';

  @override
  String get chatAiNotReady =>
      'AI engine is not ready, please initialize the model first.';

  @override
  String get chatDeviceNotSupported =>
      'The current device cannot stably run the pharmacist consultation at this moment. Please try again later.';

  @override
  String get chatEngineIncompatible =>
      'The current iOS inference engine is incompatible with the model. Please reinstall the supported engine in Model Manager.';

  @override
  String get chatAiBusy =>
      'The local pharmacist is currently busy, please try again later.';
}
