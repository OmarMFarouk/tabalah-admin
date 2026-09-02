import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/paginated_model.dart';
import '../../models/sessions_model.dart';
import '../../services/apis/sessions_api.dart';
import '../../src/app_presets.dart';
import '../base_states.dart';

// ─────────────────────────────────────────────
//  SESSIONS TABS — تبويبات الحصص
//  A session happens, people attend it, then
//  they rate it. Same object, three moments.
// ─────────────────────────────────────────────
enum SessionsTab { board, sessions, attendance, ratings }

extension SessionsTabX on SessionsTab {
  String get label => switch (this) {
    SessionsTab.board => 'اللوحة',
    SessionsTab.sessions => 'الحصص',
    SessionsTab.attendance => 'الحضور',
    SessionsTab.ratings => 'التقييمات',
  };

  IconData get icon => switch (this) {
    SessionsTab.board => Icons.view_kanban_rounded,
    SessionsTab.sessions => Icons.event_note_rounded,
    SessionsTab.attendance => Icons.how_to_reg_rounded,
    SessionsTab.ratings => Icons.star_rounded,
  };
}

class SessionsCubit extends Cubit<AppStates> {
  SessionsCubit() : super(AppInitial());
  static SessionsCubit get(context) => BlocProvider.of(context);

  final SessionsApi _api = SessionsApi();

  SessionsTab tab = SessionsTab.board;
  int page = 1;

  // Filters — الفلاتر
  int? membershipFilter;
  int? memberFilter;
  String? statusFilter;
  String? dateFilter;
  String boardFrom = AppPresets.today;
  String boardTo = AppPresets.nextMonth;

  // Data — البيانات
  Paginated<ClubSession> sessions = Paginated(items: []);
  Paginated<Attendance> attendances = Paginated(items: []);
  Paginated<SessionRating> ratings = Paginated(items: []);
  Map<String, List<ClubSession>> board = {};

  // ── Form controllers — حقول النموذج ─────────
  int? formMembershipId;
  int? formScheduleId;
  int? formUserId;
  String formDate = AppPresets.today;
  String formStatus = 'scheduled';
  TimeOfDay formStart = const TimeOfDay(hour: 16, minute: 0);
  TimeOfDay formEnd = const TimeOfDay(hour: 17, minute: 30);
  final noteCont = TextEditingController();
  String genFrom = AppPresets.today;
  String genTo = AppPresets.nextMonth;

  void clearForm() {
    formMembershipId = null;
    formScheduleId = null;
    formUserId = null;
    formDate = AppPresets.today;
    formStatus = 'scheduled';
    noteCont.clear();
  }

  void switchTab(SessionsTab t) {
    tab = t;
    page = 1;
    emit(AppInitial());
    fetch();
  }

  void setPage(int p) {
    page = p;
    fetch();
  }

  void setFilter({
    int? membership,
    int? member,
    String? status,
    String? date,
    bool clearDate = false,
  }) {
    if (membership != null) {
      membershipFilter = membership == -1 ? null : membership;
    }
    if (member != null) memberFilter = member == -1 ? null : member;
    if (status != null) statusFilter = status == '' ? null : status;
    if (clearDate) {
      dateFilter = null;
    } else if (date != null) {
      dateFilter = date;
    }
    page = 1;
    fetch();
  }

  void setBoardRange(String from, String to) {
    boardFrom = from;
    boardTo = to;
    fetch();
  }


  // The list the current tab is showing. The board isn't paginated, so it
  // reports an empty page that can never be orphaned.
  Paginated get _active => switch (tab) {
    SessionsTab.board => Paginated(items: const []),
    SessionsTab.sessions => sessions,
    SessionsTab.attendance => attendances,
    SessionsTab.ratings => ratings,
  };

  Future<void> fetch() async {
    emit(AppLoading());

    switch (tab) {
      case SessionsTab.board:
        final r = await _api.fetchBoard(from: boardFrom, to: boardTo);
        if (!r.success) return emit(AppFailure(msg: r.message));
        board = _parseBoard(r.body);
        break;

      case SessionsTab.sessions:
        final r = await _api.fetchSessions(
          membershipId: membershipFilter,
          status: statusFilter,
          date: dateFilter,
          page: page,
        );
        if (!r.success) return emit(AppFailure(msg: r.message));
        // The controller returns `sessions`, not `membership_sessions`.
        sessions = Paginated.read<ClubSession>(
          r.body,
          'sessions',
          ClubSession.fromJson,
        );
        break;

      case SessionsTab.attendance:
        final r = await _api.fetchAttendances(
          userId: memberFilter,
          membershipId: membershipFilter,
          status: statusFilter,
          date: dateFilter,
          page: page,
        );
        if (!r.success) return emit(AppFailure(msg: r.message));
        // The controller returns `attendances`, not `player_attendances`.
        attendances = Paginated.read<Attendance>(
          r.body,
          'attendances',
          Attendance.fromJson,
        );
        break;

      case SessionsTab.ratings:
        final r = await _api.fetchRatings(raterId: memberFilter, page: page);
        if (!r.success) return emit(AppFailure(msg: r.message));
        ratings = Paginated.read<SessionRating>(
          r.body,
          'session_ratings',
          SessionRating.fromJson,
        );
        break;
    }
    // The page we asked for fell off the end of the result set — a narrower
    // search, a tighter filter, or a deletion. Land on page 1 rather than
    // showing an empty table over a non-zero total.
    if (_active.isOrphanedPage) {
      page = 1;
      return fetch();
    }
    emit(AppLoaded());
  }

  // The board may arrive keyed by status, or as one flat list.
  Map<String, List<ClubSession>> _parseBoard(Map<String, dynamic> body) {
    final result = <String, List<ClubSession>>{
      for (final s in ClubSession.statuses) s: [],
    };

    final node = body['board'] ?? body['membership_sessions'] ?? body['sessions'];

    if (node is Map) {
      node.forEach((key, value) {
        if (value is List) {
          result[key.toString()] = value
              .whereType<Map>()
              .map((e) => ClubSession.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      });
      return result;
    }

    if (node is List) {
      for (final e in node.whereType<Map>()) {
        final s = ClubSession.fromJson(Map<String, dynamic>.from(e));
        result.putIfAbsent(s.status ?? 'scheduled', () => []).add(s);
      }
    }
    return result;
  }

  // ── Sessions — الحصص ────────────────────────
  Future<void> createSession() => _write(
    () => _api.createSession({
      'membership_id': formMembershipId,
      if (formScheduleId != null) 'schedule_id': formScheduleId,
      'session_date': formDate,
      'start_time': _fmt(formStart),
      'end_time': _fmt(formEnd),
      'status': formStatus,
    }),
    'تمت إضافة الحصة.',
  );

  // Idempotent — safe to re-run to top up the window.
  Future<void> generateSessions(int membershipId) => _write(
    () => _api.generateSessions(membershipId, from: genFrom, to: genTo),
    'تم توليد الحصص من المواعيد.',
  );

  // What the board's drag-and-drop calls.
  Future<void> rescheduleSession(
    int id, {
    String? date,
    TimeOfDay? start,
    TimeOfDay? end,
    String? status,
  }) => _write(
    () => _api.rescheduleSession(
      id,
      sessionDate: date,
      startTime: start == null ? null : _fmt(start),
      endTime: end == null ? null : _fmt(end),
      status: status,
    ),
    'تم تحديث الحصة.',
  );

  Future<void> moveSession(ClubSession s, String newStatus) =>
      rescheduleSession(s.id!, status: newStatus, date: s.sessionDate);

  // ── Attendance — الحضور ─────────────────────
  Future<void> recordAttendance() => _write(
    () => _api.recordAttendance({
      'user_id': formUserId,
      'membership_id': formMembershipId,
      'status': formStatus,
      'date': formDate,
      if (noteCont.text.trim().isNotEmpty) 'note': noteCont.text.trim(),
    }),
    'تم تسجيل الحضور.',
  );

  Future<void> updateAttendance(int id) => _write(
    () => _api.updateAttendance(id, {
      'status': formStatus,
      if (noteCont.text.trim().isNotEmpty) 'note': noteCont.text.trim(),
    }),
    'تم تعديل الحضور.',
  );

  Future<void> deleteAttendance(int id) =>
      _write(() => _api.deleteAttendance(id), 'تم حذف السجل.');

  // ── Ratings — التقييمات ─────────────────────
  // Feedback is moderated, not removed.
  Future<void> moderateRating(int id) {
    // The API validates `note` as required-when-present, so an empty box
    // would come back 422 rather than clearing the text.
    final note = noteCont.text.trim();
    if (note.isEmpty) {
      emit(AppFailure(msg: 'اكتب ملاحظة الإشراف أولاً.'));
      return Future.value();
    }
    return _write(
      () => _api.updateRating(id, {'note': note}),
      'تم حفظ ملاحظة الإشراف.',
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _write(Future Function() call, String okMsg) async {
    emit(AppBusy());
    final r = await call();
    if (r.success) {
      emit(AppSuccess(msg: okMsg));
      await fetch();
    } else {
      emit(AppFailure(msg: r.message));
    }
  }
}
