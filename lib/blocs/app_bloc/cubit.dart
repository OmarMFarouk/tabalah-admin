import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src/app_destinations.dart';

import '../../src/app_shared.dart';
import '../base_states.dart';

class AppCubit extends Cubit<AppStates> {
  AppCubit() : super(AppInitial()) {
    _isDark = AppShared.localStorage.getBool('theme') ?? true;
  }

  static AppCubit get(context) => BlocProvider.of(context);

  late bool _isDark;
  bool get isDark => _isDark;

  // ── Tab navigation — التنقل بين الصفحات ─────
  //  The shell (MainDashboard) owns the PageController, but screens inside
  //  it sometimes need to send the user elsewhere — a dashboard quick action
  //  jumping to Finance, say. Rather than thread a callback through every
  //  page, the shell registers its handler here on mount and screens ask for
  //  a tab by index. Null when no shell is mounted, so calls are no-ops
  //  rather than crashes during login.
  /// Set by the shell. Takes a destination id rather than an index: the
  /// index of a page depends on which pages the account may see.
  static void Function(DestinationId id)? tabRequestHandler;

  void goToPage(DestinationId id) => tabRequestHandler?.call(id);

  void switchTheme() {
    _isDark = !_isDark;
    AppShared.localStorage.setBool('theme', _isDark);
    emit(ThemeChanged());
  }
}
