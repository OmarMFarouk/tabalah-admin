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
        emails = Paginated.parse<EmailLog>(r['emails'], EmailLog.fromJson);
        break;

      case CommsTab.newsletters:
        final r = await _api.fetchNewsletters(page: page);
        if (!r.success) return emit(AppFailure(msg: r.message));
        newsletters = Paginated.parse<Newsletter>(
          r['newsletters'],
          Newsletter.fromJson,
        );
        break;
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
