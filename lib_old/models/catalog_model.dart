import 'paginated_model.dart';

// ─────────────────────────────────────────────
//  SPORT — الرياضة
// ─────────────────────────────────────────────
class Sport {
  int? id;
  String? name;
  String? description;
  String? image;
  int? trainersCount;
  int? membershipsCount;

  Sport({
    this.id,
    this.name,
    this.description,
    this.image,
    this.trainersCount,
    this.membershipsCount,
  });

  factory Sport.fromJson(Map<String, dynamic> json) => Sport(
    id: asInt(json['id']),
    name: asString(json['name']),
    description: asString(json['description']),
    image: asString(json['image']),
    trainersCount: asInt(json['trainers_count']),
    membershipsCount: asInt(json['memberships_count']),
  );

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (description != null) 'description': description,
    if (image != null) 'image': image,
  };
}

// ─────────────────────────────────────────────
//  MEMBERSHIP — الاشتراك / الحصة
//  type: scheduled (recurring) | fixed (one-off)
// ─────────────────────────────────────────────
class Membership {
  int? id;
  String? name;
  String? description;
  int? trainerId;
  int? sportId;
  double? price;
  int? durationDays;
  int? maxAttendees;
  String? type;
  String? status;
  int? enrollmentsCount;
  String? trainerName;
  String? sportName;
  List<MembershipSchedule> schedules;

  Membership({
    this.id,
    this.name,
    this.description,
    this.trainerId,
    this.sportId,
    this.price,
    this.durationDays,
    this.maxAttendees,
    this.type,
    this.status,
    this.enrollmentsCount,
    this.trainerName,
    this.sportName,
    this.schedules = const [],
  });

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      id: asInt(json['id']),
      name: asString(json['name']),
      description: asString(json['description']),
      trainerId: asInt(json['trainer_id']),
      sportId: asInt(json['sport_id']),
      price: asDouble(json['price']),
      durationDays: asInt(json['duration_days']),
      maxAttendees: asInt(json['max_attendees']),
      type: asString(json['type']),
      status: asString(json['status']),
      enrollmentsCount: asInt(json['enrollments_count']),
      trainerName: asString(json['trainer_name']),
      sportName: asString(json['sport_name']),
      schedules: (json['schedules'] is List)
          ? (json['schedules'] as List)
                .whereType<Map>()
                .map(
                  (e) =>
                      MembershipSchedule.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (description != null) 'description': description,
    if (trainerId != null) 'trainer_id': trainerId,
    if (sportId != null) 'sport_id': sportId,
    if (price != null) 'price': price,
    if (durationDays != null) 'duration_days': durationDays,
    if (maxAttendees != null) 'max_attendees': maxAttendees,
    if (type != null) 'type': type,
    if (status != null) 'status': status,
  };

  bool get isActive => status == 'active';
  String get statusAr => isActive ? 'نشط' : 'متوقف';
  String get typeAr => type == 'fixed' ? 'مرة واحدة' : 'متكرر';
  // null max_attendees means uncapped — بلا حد أقصى
  String get capacityLabel =>
      maxAttendees == null ? 'بلا حد' : '${enrollmentsCount ?? 0}/$maxAttendees';
  bool get isFull =>
      maxAttendees != null && (enrollmentsCount ?? 0) >= maxAttendees!;
  // null duration_days means open-ended — مفتوح
  String get durationLabel =>
      durationDays == null ? 'مفتوح' : '$durationDays يوم';
}

// ─────────────────────────────────────────────
//  MEMBERSHIP SCHEDULE — موعد الحصة
//  schedule_type: weekly | date
// ─────────────────────────────────────────────
class MembershipSchedule {
  int? id;
  int? membershipId;
  String? scheduleType;
  String? dayOfWeek;
  String? specificDate;
  String? startTime;
  String? endTime;
  String? membershipName;

  MembershipSchedule({
    this.id,
    this.membershipId,
    this.scheduleType,
    this.dayOfWeek,
    this.specificDate,
    this.startTime,
    this.endTime,
    this.membershipName,
  });

  factory MembershipSchedule.fromJson(Map<String, dynamic> json) =>
      MembershipSchedule(
        id: asInt(json['id']),
        membershipId: asInt(json['membership_id']),
        scheduleType: asString(json['schedule_type']),
        dayOfWeek: asString(json['day_of_week']),
        specificDate: asString(json['specific_date']),
        startTime: asString(json['start_time']),
        endTime: asString(json['end_time']),
        // Only present when the controller eager-loaded the membership.
        membershipName: asString(json['membership_name']),
      );

  Map<String, dynamic> toJson() => {
    if (membershipId != null) 'membership_id': membershipId,
    if (scheduleType != null) 'schedule_type': scheduleType,
    if (scheduleType == 'weekly' && dayOfWeek != null) 'day_of_week': dayOfWeek,
    if (scheduleType == 'date' && specificDate != null)
      'specific_date': specificDate,
    if (startTime != null) 'start_time': startTime,
    if (endTime != null) 'end_time': endTime,
  };

  bool get isWeekly => scheduleType == 'weekly';
  String get whenAr => isWeekly ? dayAr : (specificDate ?? '—');
  String get timeLabel => '${startTime ?? '--'} → ${endTime ?? '--'}';

  String get dayAr => switch (dayOfWeek) {
    'saturday' => 'السبت',
    'sunday' => 'الأحد',
    'monday' => 'الإثنين',
    'tuesday' => 'الثلاثاء',
    'wednesday' => 'الأربعاء',
    'thursday' => 'الخميس',
    'friday' => 'الجمعة',
    _ => dayOfWeek ?? '—',
  };

  // Ordered to the Saudi week: Sunday through Thursday are working
  // days, Friday and Saturday the weekend. Only the order of the
  // picker changes — the values the API stores are untouched.
  static const List<String> weekDays = [
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
  ];

  static String dayLabel(String en) => switch (en) {
    'saturday' => 'السبت',
    'sunday' => 'الأحد',
    'monday' => 'الإثنين',
    'tuesday' => 'الثلاثاء',
    'wednesday' => 'الأربعاء',
    'thursday' => 'الخميس',
    'friday' => 'الجمعة',
    _ => en,
  };
}

// ─────────────────────────────────────────────
//  ENROLLMENT — التسجيل في اشتراك
// ─────────────────────────────────────────────
class Enrollment {
  int? id;
  int? userId;
  int? membershipId;
  String? startDate;
  String? endDate;
  String? status;
  String? userName;
  String? membershipName;
  int? paymentId;
  bool isActiveNow;

  Enrollment({
    this.id,
    this.userId,
    this.membershipId,
    this.startDate,
    this.endDate,
    this.status,
    this.userName,
    this.membershipName,
    this.paymentId,
    this.isActiveNow = false,
  });

  factory Enrollment.fromJson(Map<String, dynamic> json) => Enrollment(
    id: asInt(json['id']),
    userId: asInt(json['user_id']),
    membershipId: asInt(json['membership_id']),
    startDate: asString(json['start_date']),
    endDate: asString(json['end_date']),
    status: asString(json['status']),
    userName: asString(json['user_name']),
    membershipName: asString(json['membership_name']),
    paymentId: asInt(json['payment_id']),
    // The server works out whether it is active *today*, end date included.
    isActiveNow: asBool(json['is_active']),
  );

  Map<String, dynamic> toJson() => {
    if (userId != null) 'user_id': userId,
    if (membershipId != null) 'membership_id': membershipId,
    if (startDate != null) 'start_date': startDate,
    if (endDate != null) 'end_date': endDate,
  };

  String get memberName => userName ?? '—';
  // 'expired' is not a stored status — an enrollment stays 'active' with a
  // past end_date, and the server reports that through `is_active`.
  static const List<String> statuses = [
    'active',
    'pending_payment',
    'cancelled',
  ];

  String get statusAr {
    if (status == 'active' && !isActiveNow) return 'منتهٍ';
    return statusLabel(status ?? '');
  }

  static String statusLabel(String en) => switch (en) {
    'active' => 'نشط',
    'pending_payment' => 'بانتظار الدفع',
    'cancelled' => 'ملغى',
    _ => en.isEmpty ? '—' : en,
  };
}
