import 'paginated_model.dart';

// ─────────────────────────────────────────────
//  OVERTIME — الساعات الإضافية
// ─────────────────────────────────────────────

class OvertimeRecord {
  int? id;
  int? userId;
  String? userName;
  String? userRole;
  String? date;
  double hours;
  String? note;
  String? recorderName;

  OvertimeRecord({
    this.id,
    this.userId,
    this.userName,
    this.userRole,
    this.date,
    this.hours = 0,
    this.note,
    this.recorderName,
  });

  factory OvertimeRecord.fromJson(Map<String, dynamic> json) => OvertimeRecord(
    id: asInt(json['id']),
    userId: asInt(json['user_id']),
    userName: asString(json['user_name']),
    userRole: asString(json['user_role']),
    date: asDate(json['date']),
    hours: asDouble(json['hours']) ?? 0,
    note: asString(json['note']),
    recorderName: asString(json['recorder_name']),
  );
}

/// `2` -> "2 س", `2.5` -> "2.5 س", `1.25` -> "1.25 س".
String formatHours(double hours) {
  final text = hours == hours.roundToDouble()
      ? hours.toInt().toString()
      : hours.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
  return '$text س';
}
