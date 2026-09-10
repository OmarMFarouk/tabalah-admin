import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../blocs/attendance_bloc/employee_attendance_cubit.dart';
import '../blocs/base_states.dart';
import '../src/app_colors.dart';

// ─────────────────────────────────────────────
//  حضور الموظفين — GPS clock-in register
//  Left: the fence. Right: who clocked in.
// ─────────────────────────────────────────────

/// The fence and the register, side by side.
///
/// They belong on one screen because they are one question: "did this count?"
/// is answered by where the person was *and* where the fence was, and staff
/// checking a disputed day should not have to hold one of them in their head
/// while navigating to the other.
class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EmployeeAttendanceCubit()..load(),
      child: BlocBuilder<EmployeeAttendanceCubit, AppStates>(
        builder: (context, state) {
          final cubit = EmployeeAttendanceCubit.get(context);

          return Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, box) {
                // Stack below ~1100px: two half-width panes make both the
                // map and the table unusable on a laptop screen.
                final wide = box.maxWidth >= 1100;
                final fence = _FencePane(cubit: cubit);
                final register = _RegisterPane(cubit: cubit);

                if (!wide) {
                  return ListView(
                    children: [
                      SizedBox(height: 460, child: fence),
                      const SizedBox(height: 20),
                      SizedBox(height: 520, child: register),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 4, child: fence),
                    const SizedBox(width: 20),
                    Expanded(flex: 6, child: register),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Drag the pin, set the radius, save.
class _FencePane extends StatefulWidget {
  final EmployeeAttendanceCubit cubit;

  const _FencePane({required this.cubit});

  @override
  State<_FencePane> createState() => _FencePaneState();
}

class _FencePaneState extends State<_FencePane> {
  final _map = MapController();
  LatLng? _pin;
  double _radius = 150;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final f = widget.cubit.fence;
    // Adopt the saved fence once, then leave the pin alone - a reload while
    // someone is dragging must not yank it back.
    if (f != null && _pin == null) {
      _pin = LatLng(f.latitude, f.longitude);
      _radius = f.radiusMeters.toDouble();
    }
  }

  Future<void> _save() async {
    if (_pin == null) return;
    setState(() => _saving = true);
    final error = await widget.cubit.saveFence(
      latitude: _pin!.latitude,
      longitude: _pin!.longitude,
      radiusMeters: _radius.round(),
    );
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'تم حفظ نطاق الحضور'),
        backgroundColor: error != null ? Colors.red.shade700 : AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final centre = _pin ?? const LatLng(24.7135517, 46.6752957);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('نطاق تسجيل الحضور',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'اضغط على الخريطة لتحديد موقع الأكاديمية، ثم اختر نصف القطر.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: centre,
                initialZoom: 15,
                onTap: (_, p) => setState(() => _pin = p),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // OSM's tile policy requires identifying the client.
                  userAgentPackageName: 'com.tabalah.admin',
                ),
                if (_pin != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _pin!,
                        // The circle is drawn in real metres, so what staff
                        // see is the fence, not an approximation of it.
                        radius: _radius,
                        useRadiusInMeter: true,
                        color: AppColors.primary.withValues(alpha: .18),
                        borderColor: AppColors.primary,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                if (_pin != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pin!,
                        width: 40,
                        height: 40,
                        child: Icon(Icons.location_on,
                            color: AppColors.primary, size: 38),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('نصف القطر'),
                    const Spacer(),
                    Text('${_radius.round()} متر',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _radius,
                  // 25m floor matches the server rule: phone GPS is routinely
                  // off by 10-20m, and a tighter fence rejects honest staff.
                  min: 25,
                  max: 1000,
                  divisions: 39,
                  label: '${_radius.round()} م',
                  onChanged: (v) => setState(() => _radius = v),
                ),
                const SizedBox(height: 4),
                FilledButton.icon(
                  onPressed: (_pin == null || _saving) ? null : _save,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ النطاق'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterPane extends StatelessWidget {
  final EmployeeAttendanceCubit cubit;

  const _RegisterPane({required this.cubit});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                const Text('سجل حضور الموظفين',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (cubit.date != null)
                  TextButton.icon(
                    onPressed: () => cubit.setDate(null),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('كل الأيام'),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      cubit.setDate(
                          picked.toIso8601String().split('T').first);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(cubit.date ?? 'اختر يوماً'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cubit.rows.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('لا يوجد حضور مسجّل لهذا اليوم',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                : ListView.separated(
                    itemCount: cubit.rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final r = cubit.rows[i];
                      return ListTile(
                        leading: Icon(Icons.check_circle_rounded,
                            color: AppColors.primary),
                        title: Text(r.employeeName),
                        subtitle: Text(r.date),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(r.checkedInAt.length >= 16
                                ? r.checkedInAt.substring(11, 16)
                                : r.checkedInAt),
                            // Distance is the audit trail: it is what makes a
                            // disputed row answerable months later.
                            Text('${r.distanceMeters} م من المركز',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
