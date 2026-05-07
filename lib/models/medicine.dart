import 'package:isar/isar.dart';

part 'medicine.g.dart';

@collection
class Medicine {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String name; // 药名：阿莫西林

  String? dosage; // 剂量：2粒
  String? frequency; // 频次：每日3次
  String? instruction; // 医嘱原文
  String? note; // 注意事项：忌酒

  final reminders = IsarLinks<Reminder>(); // 关联多个提醒时间
}

@collection
class Reminder {
  Id id = Isar.autoIncrement;

  late int hour; // 小时：12
  late int minute; // 分钟：30
  bool isActive = true; // 是否开启

  @Backlink(to: 'reminders')
  final medicine = IsarLink<Medicine>();
}

@collection
class IntakeLog {
  Id id = Isar.autoIncrement;

  late DateTime planTime; // 计划时间
  DateTime? actualTime; // 实际服用时间
  late String medicineName; // 冗余药名
  bool isTaken = false; // 是否已吃

  final medicine = IsarLink<Medicine>(); // 强关联：用药所属药品
}
