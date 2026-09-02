// ─────────────────────────────────────────────
//  SHARED STATES — الحالات المشتركة
//  Every cubit in the panel emits these, so the
//  screens all listen for the same five things.
// ─────────────────────────────────────────────
abstract class AppStates {}

class AppInitial extends AppStates {}

// The list is being fetched — لا يمسح البيانات الحالية
class AppLoading extends AppStates {}

// A write is in flight — يعطّل أزرار الحفظ
class AppBusy extends AppStates {}

class AppLoaded extends AppStates {}

class AppSuccess extends AppStates {
  final String msg;
  // Tells an open dialog to close itself.
  final bool shouldPop;
  AppSuccess({required this.msg, this.shouldPop = true});
}

class AppFailure extends AppStates {
  final String msg;
  AppFailure({required this.msg});
}

class ThemeChanged extends AppStates {}
