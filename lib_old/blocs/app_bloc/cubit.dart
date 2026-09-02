import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src/app_shared.dart';
import '../base_states.dart';

class AppCubit extends Cubit<AppStates> {
  AppCubit() : super(AppInitial()) {
    _isDark = AppShared.localStorage.getBool('theme') ?? true;
  }

  static AppCubit get(context) => BlocProvider.of(context);

  late bool _isDark;
  bool get isDark => _isDark;

  void switchTheme() {
    _isDark = !_isDark;
    AppShared.localStorage.setBool('theme', _isDark);
    emit(ThemeChanged());
  }
}
