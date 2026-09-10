import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/apis/api_client.dart';
import '../../src/app_endpoints.dart';
import '../base_states.dart';

/// Where the fence is and how wide. Mirrors `geofence_settings`, which is a
/// single row - see the backend migration for why it is not a settings
/// table.
class Geofence {
  final double latitude;
  final double longitude;
  final int radiusMeters;

  const Geofence({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  factory Geofence.fromJson(Map<String, dynamic> j) => Geofence(
        latitude: double.tryParse('${j['latitude']}') ?? 0,
        longitude: double.tryParse('${j['longitude']}') ?? 0,
        radiusMeters: int.tryParse('${j['radius_meters']}') ?? 150,
      );
}

class EmployeeAttendanceRow {
  final int id;
  final String employeeName;
  final String date;
  final String checkedInAt;
  final int distanceMeters;

  const EmployeeAttendanceRow({
    required this.id,
    required this.employeeName,
    required this.date,
    required this.checkedInAt,
    required this.distanceMeters,
  });

  factory EmployeeAttendanceRow.fromJson(Map<String, dynamic> j) =>
      EmployeeAttendanceRow(
        id: int.tryParse('${j['id']}') ?? 0,
        employeeName: (j['user']?['name'] ?? '—').toString(),
        date: (j['date'] ?? '').toString(),
        checkedInAt: (j['checked_in_at'] ?? '').toString(),
        distanceMeters: int.tryParse('${j['distance_meters']}') ?? 0,
      );
}

class EmployeeAttendanceCubit extends Cubit<AppStates> {
  EmployeeAttendanceCubit() : super(AppInitial());
  static EmployeeAttendanceCubit get(context) => BlocProvider.of(context);

  Geofence? fence;
  List<EmployeeAttendanceRow> rows = [];

  /// Null means "every day". The register defaults to today because that is
  /// the question staff actually open this screen to answer.
  String? date;

  String? error;

  Future<void> load() async {
    emit(AppBusy());
    error = null;

    final fenceRes = await ApiClient.get(AppEndPoints.geofence);
    if (fenceRes.success) {
      final g = fenceRes.body['data']?['geofence'] ?? fenceRes.body['geofence'];
      if (g is Map<String, dynamic>) fence = Geofence.fromJson(g);
    } else {
      error = fenceRes.message;
    }

    final res = await ApiClient.get(
      AppEndPoints.employeeAttendances,
      query: date == null ? null : {'date': date},
    );
    if (res.success) {
      final list = res.body['data']?['attendances'] ?? res.body['attendances'];
      rows = (list is List)
          ? list
              .whereType<Map<String, dynamic>>()
              .map(EmployeeAttendanceRow.fromJson)
              .toList()
          : [];
    } else {
      error = res.message;
    }

    emit(error == null ? AppLoaded() : AppFailure(msg: error!));
  }

  void setDate(String? value) {
    date = value;
    load();
  }

  /// Returns null on success, otherwise the server's message.
  ///
  /// Reloads afterwards rather than patching local state: moving the fence
  /// changes what the server considers in range, and the saved value is the
  /// one worth showing.
  Future<String?> saveFence({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    final res = await ApiClient.put(AppEndPoints.geofence, data: {
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
    });

    if (!res.success) return res.message;
    await load();
    return null;
  }
}
