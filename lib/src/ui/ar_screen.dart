import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sun_tracker/src/ar/sky_painter.dart';
import 'package:sun_tracker/src/ar/sun_scene.dart';
import 'package:sun_tracker/src/astronomy/sun_calculator.dart';
import 'package:sun_tracker/src/sensors/device_info.dart';
import 'package:sun_tracker/src/sensors/device_orientation_source.dart';
import 'package:sun_tracker/src/settings/calibration.dart';
import 'package:sun_tracker/src/ui/calibration_sheet.dart';
import 'package:sun_tracker/src/ui/local_minutes.dart';
import 'package:sun_tracker/src/ui/overlay_widgets.dart';
import 'package:sun_tracker/src/ui/sun_info_card.dart';
import 'package:sun_tracker/src/ui/time_controls.dart';

enum _LocationStatus {
  searching,
  serviceDisabled,
  denied,
  deniedForever,
  ready,
}

/// Typical field of view along the long side of a phone's main camera.
const double _defaultFieldOfView = 67;

/// Space at the bottom of the screen that is covered by the controls.
const double _bottomControlsHeight = 330;

class ArScreen extends StatefulWidget {
  const ArScreen({required this.calibration, super.key});

  final Calibration calibration;

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> with WidgetsBindingObserver {
  final _orientation = DeviceOrientationSource();

  CameraController? _camera;
  String? _cameraError;
  double _fieldOfView = _defaultFieldOfView;
  double _zoom = 1;
  double _minZoom = 1;
  double _maxZoom = 8;
  double _zoomAtScaleStart = 1;

  _LocationStatus _locationStatus = _LocationStatus.searching;
  StreamSubscription<Position>? _positionSubscription;
  Position? _position;
  double? _declination;
  SunCalculator? _calculator;

  double _minutes = LocalMinutes.of(DateTime.now());
  bool _isLive = true;
  Timer? _clock;

  SunScene? _scene;
  int? _sceneDay;
  SunPosition? _selectedSun;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _orientation.start();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _start();
  }

  Future<void>? _starting;
  bool _cameraStarting = false;

  Future<void> _start() {
    return _starting ??= () async {
      try {
        await _initLocation();
        await _initCamera();
      } finally {
        _starting = null;
      }
    }();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _positionSubscription?.cancel();
    _camera?.dispose();
    _orientation.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _orientation.stop();
        final camera = _camera;
        _camera = null;
        camera?.dispose();
      case AppLifecycleState.resumed:
        _orientation.start();
        if (_starting == null) {
          if (_locationStatus != _LocationStatus.ready) {
            _start();
          } else {
            _initCamera();
          }
        }
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _initLocation() async {
    if (_positionSubscription != null) {
      return;
    }
    if (_locationStatus != _LocationStatus.searching) {
      setState(() => _locationStatus = _LocationStatus.searching);
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _locationStatus = _LocationStatus.serviceDisabled);
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) {
      return;
    }
    switch (permission) {
      case LocationPermission.denied || LocationPermission.unableToDetermine:
        setState(() => _locationStatus = _LocationStatus.denied);
        return;
      case LocationPermission.deniedForever:
        setState(() => _locationStatus = _LocationStatus.deniedForever);
        return;
      case LocationPermission.whileInUse || LocationPermission.always:
        break;
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      _setPosition(lastKnown);
    }
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 200,
          ),
        ).listen(
          _setPosition,
          onError: (Object _) {
            _positionSubscription?.cancel();
            _positionSubscription = null;
            if (mounted && _position == null) {
              setState(() => _locationStatus = _LocationStatus.serviceDisabled);
            }
          },
        );
  }

  void _setPosition(Position position) {
    if (!mounted) {
      return;
    }
    setState(() {
      _position = position;
      _locationStatus = _LocationStatus.ready;
      _calculator = SunCalculator(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _declination = DeviceInfo.magneticDeclination(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
      );
      _sceneDay = null;
      _updateSun();
    });
  }

  Future<void> _initCamera() async {
    if (_camera != null || _cameraStarting) {
      return;
    }
    _cameraStarting = true;
    try {
      final cameras = await availableCameras();
      final description =
          cameras
              .where(
                (camera) => camera.lensDirection == CameraLensDirection.back,
              )
              .firstOrNull ??
          cameras.firstOrNull;
      if (description == null) {
        setState(() => _cameraError = 'No camera found');
        return;
      }
      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _camera = controller;
      await controller.initialize();
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      final fieldOfView = await DeviceInfo.cameraFieldOfView(description.name);
      if (!mounted || _camera != controller) {
        await controller.dispose();
        return;
      }
      _zoom = _zoom.clamp(minZoom, math.min(maxZoom, 10));
      await controller.setZoomLevel(_zoom);
      setState(() {
        _cameraError = null;
        _minZoom = minZoom;
        _maxZoom = math.min(maxZoom, 10);
        if (fieldOfView != null && fieldOfView > 10 && fieldOfView < 150) {
          _fieldOfView = fieldOfView;
        }
      });
    } on CameraException catch (exception) {
      _camera = null;
      if (mounted) {
        setState(() {
          _cameraError = exception.code == 'CameraAccessDenied'
              ? 'Camera access denied, showing the sky without the camera'
              : (exception.description ?? exception.code);
        });
      }
    } finally {
      _cameraStarting = false;
    }
  }

  void _tick() {
    if (_isLive) {
      setState(() {
        _minutes = LocalMinutes.of(DateTime.now());
        _updateSun();
      });
    }
  }

  void _updateSun() {
    final calculator = _calculator;
    if (calculator == null) {
      return;
    }
    final day = LocalMinutes.dayIndex(_minutes);
    if (_sceneDay != day) {
      _sceneDay = day;
      _scene = SunScene.compute(calculator, LocalMinutes.dateOfDay(day));
    }
    _selectedSun = calculator.positionAt(LocalMinutes.toDateTime(_minutes));
  }

  void _setMinutes(double minutes) {
    setState(() {
      _isLive = false;
      _minutes = minutes;
      _updateSun();
    });
  }

  void _setDay(double minutes) {
    final day = LocalMinutes.dayIndex(_minutes);
    final minuteOfDay = _minutes - day * LocalMinutes.perDay;
    final newDay = ((minutes - minuteOfDay) / LocalMinutes.perDay).round();
    if (newDay != day) {
      _setMinutes(newDay * LocalMinutes.perDay + minuteOfDay);
    }
  }

  void _resetToNow() {
    setState(() {
      _isLive = true;
      _minutes = LocalMinutes.of(DateTime.now());
      _updateSun();
    });
  }

  Future<void> _pickDate() async {
    final current = LocalMinutes.toDateTime(_minutes);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (picked == null) {
      return;
    }
    final day = LocalMinutes.dayIndex(_minutes);
    final minuteOfDay = _minutes - day * LocalMinutes.perDay;
    _setMinutes(
      LocalMinutes.dayIndexOf(picked) * LocalMinutes.perDay + minuteOfDay,
    );
  }

  void _setZoom(double zoom) {
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    if (clamped == _zoom) {
      return;
    }
    setState(() => _zoom = clamped);
    _camera?.setZoomLevel(clamped).catchError((Object _) {});
  }

  void _showCalibration() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => CalibrationSheet(
        calibration: widget.calibration,
        detectedFieldOfView: _fieldOfView,
        declination: _declination,
      ),
    );
  }

  Size get _portraitPreviewSize {
    final previewSize = _camera?.value.previewSize;
    if (previewSize == null) {
      return const Size(3, 4);
    }
    return Size(
      math.min(previewSize.width, previewSize.height),
      math.max(previewSize.width, previewSize.height),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final previewSize = _portraitPreviewSize;
          final coverScale = math.max(
            size.width / previewSize.width,
            size.height / previewSize.height,
          );
          final longSide = previewSize.height * coverScale;
          return Stack(
            children: [
              Positioned.fill(
                child: CameraBackground(
                  controller: _camera,
                  previewSize: previewSize,
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  onScaleStart: (_) => _zoomAtScaleStart = _zoom,
                  onScaleUpdate: (details) {
                    if (details.pointerCount >= 2) {
                      _setZoom(_zoomAtScaleStart * details.scale);
                    }
                  },
                  onDoubleTap: () => _setZoom(1),
                  child: ListenableBuilder(
                    listenable: widget.calibration,
                    builder: (context, _) {
                      final fieldOfView =
                          _fieldOfView *
                          widget.calibration.fieldOfViewScale *
                          math.pi /
                          180;
                      return CustomPaint(
                        size: size,
                        painter: SkyPainter(
                          orientation: _orientation,
                          northOffset: _northOffset,
                          focalLength:
                              longSide / 2 / math.tan(fieldOfView / 2) * _zoom,
                          scene: _scene,
                          selected: _selectedSun,
                          overlayInsets: EdgeInsets.only(
                            top: mediaPadding.top + 56,
                            bottom: _bottomControlsHeight + mediaPadding.bottom,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ListenableBuilder(
                                listenable: widget.calibration,
                                builder: (context, _) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: HeadingIndicator(
                                    orientation: _orientation,
                                    northOffset: _northOffset,
                                  ),
                                ),
                              ),
                            ),
                            if (_zoom > 1.05)
                              TextButton(
                                onPressed: () => _setZoom(1),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                ),
                                child: Text('${_zoom.toStringAsFixed(1)}×'),
                              ),
                            IconButton(
                              tooltip: 'Calibration',
                              color: Colors.white,
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xB31C1B22),
                              ),
                              onPressed: _showCalibration,
                              icon: const Icon(Icons.tune),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: CompassAccuracyWarning(
                            orientation: _orientation,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_cameraError case final error?)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(
                          error,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _InfoOrStatus(
                        status: _locationStatus,
                        position: _position,
                        scene: _scene,
                        sun: _selectedSun,
                        minutes: _minutes,
                        onRetry: _start,
                      ),
                    ),
                    TimeControls(
                      minutes: _minutes,
                      isLive: _isLive,
                      onMinutesChanged: _setMinutes,
                      onDayChanged: _setDay,
                      onResetToNow: _resetToNow,
                      onPickDate: _pickDate,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double get _northOffset =>
      ((_declination ?? 0) + widget.calibration.headingOffset) * math.pi / 180;
}

class _InfoOrStatus extends StatelessWidget {
  const _InfoOrStatus({
    required this.status,
    required this.position,
    required this.scene,
    required this.sun,
    required this.minutes,
    required this.onRetry,
  });

  final _LocationStatus status;
  final Position? position;
  final SunScene? scene;
  final SunPosition? sun;
  final double minutes;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final position = this.position;
    final scene = this.scene;
    final sun = this.sun;
    if (position != null && scene != null && sun != null) {
      return SunInfoCard(
        date: LocalMinutes.toDateTime(minutes),
        day: scene.day,
        sun: sun,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }
    return switch (status) {
      _LocationStatus.searching || _LocationStatus.ready => const StatusMessage(
        message: 'Finding your location',
      ),
      _LocationStatus.serviceDisabled => StatusMessage(
        icon: Icons.location_off,
        message: 'Location services are turned off',
        actionLabel: 'Open settings',
        onAction: () async {
          await Geolocator.openLocationSettings();
        },
      ),
      _LocationStatus.denied => StatusMessage(
        icon: Icons.location_disabled,
        message: 'Your location is needed to calculate where the sun is',
        actionLabel: 'Try again',
        onAction: onRetry,
      ),
      _LocationStatus.deniedForever => StatusMessage(
        icon: Icons.location_disabled,
        message:
            'Location access is blocked, allow it in the app settings to see '
            'the sun',
        actionLabel: 'Open settings',
        onAction: () async {
          await Geolocator.openAppSettings();
        },
      ),
    };
  }
}
