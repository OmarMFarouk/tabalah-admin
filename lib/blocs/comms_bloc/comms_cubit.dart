import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/paginated_model.dart';
import '../../models/performance_model.dart';
import '../../services/apis/comms_api.dart';
import '../base_states.dart';

// ─────────────────────────────────────────────
//  COMMS TABS — تبويبات المراسلات
//  Split by blast radius: one-off mail reaches
//  one member, a newsletter reaches everyone.
// ─────────────────────────────────────────────
enum CommsTab { emails, newsletters }

extension CommsTabX on CommsTab {
  String get label => switch (this) {
    CommsTab.emails => 'سجل البريد',
    CommsTab.newsletters => 'النشرات',
  };

  IconData get icon => switch (this) {
    CommsTab.emails => Icons.mark_email_read_rounded,
    CommsTab.newsletters => Icons.campaign_rounded,
  };
}

class CommsCubit extends Cubit<AppStates> {
  CommsCubit() : super(AppInitial());
  static CommsCubit get(context) => BlocProvider.of(context);

  final CommsApi _api = CommsApi();

  CommsTab tab = CommsTab.emails;
  int page = 1;

  final TextEditingController searchCont = TextEditingController();
  String? typeFilter;

  Paginated<EmailLog> emails = Paginated(items: []);
  Paginated<Newsletter> newsletters = Paginated(items: []);

  // ── Compose — إنشاء رسالة ───────────────────
  final subjectCont = TextEditingController();
  final bodyCont = TextEditingController();
  int? formUserId;
  String formAudience = 'players';
  List<int> customIds = [];

  void clearForm() {
    subjectCont.clear();
    bodyCont.clear();
    formUserId = null;
    formAudience = 'players';
    customIds = [];
  }

  void toggleCustomId(int id) {
    customIds.contains(id) ? customIds.remove(id) : customIds.add(id);
    emit(AppInitial());
  }

  void switchTab(CommsTab t) {
    tab = t;
    page = 1;
    searchCont.clear();
    emit(AppInitial());
    fetch();
  }

  void setPage(int p) {
    page = p;
    fetch();
  }

  void setFilter({String? type}) {
    if (type != null) typeFilter = type.isEmpty ? null : type;
    page = 1;
    fetch();
  }


  Paginated get _active => switch (tab) {
    CommsTab.emails => emails,
    CommsTab.newsletters => newsletters,
  };

  // ── SEARCH — البحث ──────────────────────────
  //  A new query is a NEW result set. Page 3 of the old one is meaningless
  //  against it and the server rightly answers with nothing, which reads on
  //  screen as "no results" when there may be plenty on page 1. So every
  //  search starts from the first page; the pager takes over from there.
  void search() {
    page = 1;
    fetch();
  }

  Future<void> fetch() async {
    emit(AppLoading());

    switch (tab) {
      case CommsTab.emails:
        final r = await _api.fetchEmails(
          type: typeFilter,
          q: searchCont.text.trim(),
          page: page,
        );
        if (!r.success) return emit(AppFailure(msg: r.message));
        // EmailController answers with `email_logs`.
        emails = Paginated.read<EmailLog>(
          r.body,
          'email_logs',
          EmailLog.fromJson,
        );
        break;

      case CommsTab.newsletters:
        final r = await _api.fetchNewsletters(page: page);
        if (!r.success) return emit(AppFailure(msg: r.message));
        newsletters = Paginated.read<Newsletter>(
          r.body,
          'newsletters',
          Newsletter.fromJson,
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

  // A single message to one member — open to all staff.
  Future<void> sendCustom() {
    if (formUserId == null) {
      emit(AppFailure(msg: 'اختر المستلم أولاً.'));
      return Future.value();
    }
    return _write(
      () => _api.sendCustom(
        userId: formUserId,
        subject: subjectCont.text.trim(),
        body: bodyCont.text.trim(),
      ),
      'تم إرسال الرسالة.',
    );
  }

  // Mass mail — admin and owner only.
  Future<void> sendNewsletter() {
    if (formAudience == 'custom' && customIds.isEmpty) {
      emit(AppFailure(msg: 'اختر مستلماً واحداً على الأقل للقائمة المخصصة.'));
      return Future.value();
    }
    return _write(
      () => _api.sendNewsletter(
        audience: formAudience,
        subject: subjectCont.text.trim(),
        body: bodyCont.text.trim(),
        userIds: customIds,
      ),
      'تم إرسال النشرة.',
    );
  }

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
