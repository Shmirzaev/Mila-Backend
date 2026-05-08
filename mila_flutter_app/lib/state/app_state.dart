import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_config.dart';
import '../models/employee_record.dart';
import '../services/employee_directory_service.dart';
import '../services/livekit_service.dart';
import '../services/settings_service.dart';
import '../services/token_service.dart';

enum AppConnectionStatus { disconnected, connecting, connected, error }

class AppState extends ChangeNotifier {
  AppState({
    required EmployeeDirectoryService employeeDirectoryService,
    required SettingsService settingsService,
    required TokenService tokenService,
    required LiveKitService liveKitService,
  }) : _employeeDirectoryService = employeeDirectoryService,
       _settingsService = settingsService,
       _tokenService = tokenService,
       _liveKitService = liveKitService;

  final EmployeeDirectoryService _employeeDirectoryService;
  final SettingsService _settingsService;
  final TokenService _tokenService;
  final LiveKitService _liveKitService;

  EventsListener<RoomEvent>? _roomEvents;
  bool _disposed = false;
  bool _hasAttemptedAutoConnect = false;

  String _backendBaseUrl = '';
  String? _errorMessage;
  AppConnectionStatus _status = AppConnectionStatus.disconnected;
  bool _isMicrophoneEnabled = false;
  bool _isCameraEnabled = false;
  bool _cameraEnabledOnConnect = false;
  CameraPosition _cameraPosition = CameraPosition.front;
  List<String> _remoteParticipantNames = const <String>[];
  List<EmployeeRecord> _employeeDirectory = const <EmployeeRecord>[];
  bool _isEmployeeDirectoryLoading = false;
  String? _employeeDirectoryError;

  String get backendBaseUrl => _backendBaseUrl;
  String? get errorMessage => _errorMessage;
  AppConnectionStatus get status => _status;
  bool get isConnected => _status == AppConnectionStatus.connected;
  bool get isConnecting => _status == AppConnectionStatus.connecting;
  bool get hasBackendBaseUrl => _backendBaseUrl.isNotEmpty;
  bool get isMicrophoneEnabled => _isMicrophoneEnabled;
  bool get isCameraEnabled =>
      isConnected ? _isCameraEnabled : _cameraEnabledOnConnect;
  CameraPosition get cameraPosition => _cameraPosition;
  bool get isUsingBackCamera => _cameraPosition == CameraPosition.back;
  LocalVideoTrack? get localVideoTrack {
    final participant = _liveKitService.room?.localParticipant;
    final publication = participant?.getTrackPublicationBySource(
      TrackSource.camera,
    );
    final track = publication?.track;
    return track is LocalVideoTrack ? track : null;
  }

  Room? get liveKitRoom => _liveKitService.room;

  bool get canDisconnect => _liveKitService.room != null || isConnecting;
  List<String> get remoteParticipantNames =>
      List<String>.unmodifiable(_remoteParticipantNames);
  List<EmployeeRecord> get employeeDirectory =>
      List<EmployeeRecord>.unmodifiable(_employeeDirectory);
  bool get isEmployeeDirectoryLoading => _isEmployeeDirectoryLoading;
  String? get employeeDirectoryError => _employeeDirectoryError;
  bool get hasEmployeeDirectory => _employeeDirectory.isNotEmpty;

  String get participantSource {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'flutter';
    }
  }

  String get participantIdentity => '$participantSource-user';

  String get participantName => 'Beknazar $platformLabel';

  String get platformLabel {
    if (kIsWeb) {
      return 'Web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      default:
        return 'Flutter';
    }
  }

  Future<void> initialize() async {
    final storedUrl = await _settingsService.readBackendBaseUrl();
    _backendBaseUrl = _resolveInitialBackendBaseUrl(storedUrl);
    _safeNotifyListeners();

    if (hasBackendBaseUrl) {
      unawaited(refreshEmployeeDirectory());
    }
  }

  Future<void> maybeAutoConnectOnLaunch() async {
    if (_hasAttemptedAutoConnect ||
        !AppConfig.autoConnectOnLaunch ||
        !hasBackendBaseUrl) {
      return;
    }

    _hasAttemptedAutoConnect = true;
    await connect();
  }

  Future<void> saveBackendBaseUrl(String value) async {
    final normalized = _normalizeBackendBaseUrl(value);
    await _settingsService.saveBackendBaseUrl(normalized);
    _backendBaseUrl = normalized;
    _errorMessage = null;
    _safeNotifyListeners();
    await refreshEmployeeDirectory();
  }

  Future<void> refreshEmployeeDirectory({int limit = 250}) async {
    if (!hasBackendBaseUrl) {
      _employeeDirectory = const <EmployeeRecord>[];
      _employeeDirectoryError = null;
      _isEmployeeDirectoryLoading = false;
      _safeNotifyListeners();
      return;
    }

    _isEmployeeDirectoryLoading = true;
    _employeeDirectoryError = null;
    _safeNotifyListeners();

    try {
      final employees = await _employeeDirectoryService.fetchEmployees(
        backendBaseUrl: _backendBaseUrl,
        limit: limit,
      );
      _employeeDirectory = employees;
      _employeeDirectoryError = null;
    } on EmployeeDirectoryServiceException catch (error) {
      _employeeDirectory = const <EmployeeRecord>[];
      _employeeDirectoryError = error.message;
    } catch (error) {
      _employeeDirectory = const <EmployeeRecord>[];
      _employeeDirectoryError = 'Could not load employees: $error';
    } finally {
      _isEmployeeDirectoryLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> connect() async {
    if (isConnecting || isConnected) {
      return;
    }

    if (!hasBackendBaseUrl) {
      _setBlockingError('A backend URL is required before Mila can connect.');
      return;
    }

    _status = AppConnectionStatus.connecting;
    _errorMessage = null;
    _safeNotifyListeners();

    String? nonBlockingError;

    try {
      await _ensureMicrophonePermission();

      if (_cameraEnabledOnConnect) {
        try {
          await _ensureCameraPermission();
        } on _PermissionDeniedException catch (error) {
          _cameraEnabledOnConnect = false;
          nonBlockingError = error.message;
        }
      }

      final token = await _tokenService.fetchToken(
        backendBaseUrl: _backendBaseUrl,
        participantIdentity: participantIdentity,
        participantName: participantName,
        participantSource: participantSource,
      );

      final room = await _liveKitService.connect(
        serverUrl: token.serverUrl,
        participantToken: token.participantToken,
      );

      await _attachRoom(room);

      _isMicrophoneEnabled = true;
      _status = AppConnectionStatus.connected;
      _errorMessage = null;
      _syncRemoteParticipants();

      if (_cameraEnabledOnConnect) {
        try {
          await _liveKitService.setCameraEnabled(
            true,
            cameraCaptureOptions: _cameraCaptureOptions(),
          );
          _isCameraEnabled = true;
        } on LiveKitServiceException catch (error) {
          _cameraEnabledOnConnect = false;
          _isCameraEnabled = false;
          nonBlockingError =
              'Connected to Mila, but the camera could not be enabled: ${error.message}';
        }
      }

      _errorMessage = nonBlockingError;
      unawaited(refreshEmployeeDirectory());
      _safeNotifyListeners();
    } on _PermissionDeniedException catch (error) {
      await _handleConnectFailure(error.message);
    } on TokenServiceException catch (error) {
      await _handleConnectFailure(error.message);
    } on LiveKitServiceException catch (error) {
      await _handleConnectFailure(error.message);
    } catch (error) {
      await _handleConnectFailure('Unexpected connection error: $error');
    }
  }

  Future<void> disconnect() async {
    await _detachRoom();
    await _liveKitService.disconnect();

    _status = AppConnectionStatus.disconnected;
    _errorMessage = null;
    _isMicrophoneEnabled = false;
    _isCameraEnabled = false;
    _remoteParticipantNames = const <String>[];
    _safeNotifyListeners();
  }

  Future<void> toggleMicrophone() async {
    if (!isConnected) {
      return;
    }

    final shouldEnable = !_isMicrophoneEnabled;

    try {
      if (shouldEnable) {
        await _ensureMicrophonePermission();
      }

      await _liveKitService.setMicrophoneEnabled(shouldEnable);
      _isMicrophoneEnabled = shouldEnable;
      _errorMessage = null;
      _safeNotifyListeners();
    } on _PermissionDeniedException catch (error) {
      _errorMessage = error.message;
      _safeNotifyListeners();
    } on LiveKitServiceException catch (error) {
      _errorMessage = error.message;
      _safeNotifyListeners();
    }
  }

  Future<void> toggleCamera() async {
    if (!isConnected) {
      _cameraEnabledOnConnect = !_cameraEnabledOnConnect;
      _errorMessage = null;
      _safeNotifyListeners();
      return;
    }

    final shouldEnable = !_isCameraEnabled;

    try {
      if (shouldEnable) {
        await _ensureCameraPermission();
      }

      await _liveKitService.setCameraEnabled(
        shouldEnable,
        cameraCaptureOptions: shouldEnable ? _cameraCaptureOptions() : null,
      );
      _isCameraEnabled = shouldEnable;
      _cameraEnabledOnConnect = shouldEnable;
      _errorMessage = null;
      _safeNotifyListeners();
    } on _PermissionDeniedException catch (error) {
      _errorMessage = error.message;
      _safeNotifyListeners();
    } on LiveKitServiceException catch (error) {
      _errorMessage = error.message;
      _safeNotifyListeners();
    }
  }

  Future<void> switchCameraFacing() async {
    final nextPosition = _cameraPosition.switched();

    if (!isConnected || !_isCameraEnabled || localVideoTrack == null) {
      _cameraPosition = nextPosition;
      _errorMessage = null;
      _safeNotifyListeners();
      return;
    }

    try {
      await _liveKitService.setCameraPosition(nextPosition);
      _cameraPosition = nextPosition;
      _errorMessage = null;
      _safeNotifyListeners();
    } on LiveKitServiceException catch (error) {
      _errorMessage = error.message;
      _safeNotifyListeners();
    }
  }

  Future<void> sendTextMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    if (!isConnected) {
      _errorMessage = 'Connect to Mila before sending a text message.';
      _safeNotifyListeners();
      throw const LiveKitServiceException(
        'Connect to Mila before sending a text message.',
      );
    }

    try {
      await _liveKitService.sendTextMessage(trimmed);
      _errorMessage = null;
      _safeNotifyListeners();
    } on LiveKitServiceException catch (error) {
      _errorMessage = error.message;
      _safeNotifyListeners();
      rethrow;
    }
  }

  String get statusLabel {
    switch (_status) {
      case AppConnectionStatus.disconnected:
        return 'Disconnected';
      case AppConnectionStatus.connecting:
        return 'Connecting';
      case AppConnectionStatus.connected:
        return 'Connected';
      case AppConnectionStatus.error:
        return 'Error';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_detachRoom());
    unawaited(_liveKitService.disconnect());
    _employeeDirectoryService.dispose();
    _tokenService.dispose();
    super.dispose();
  }

  Future<void> _attachRoom(Room room) async {
    await _detachRoom();

    room.addListener(_handleRoomChanged);

    _roomEvents = room.createListener()
      ..on<RoomDisconnectedEvent>((event) {
        _isMicrophoneEnabled = false;
        _isCameraEnabled = false;
        _remoteParticipantNames = const <String>[];

        if (event.reason == DisconnectReason.clientInitiated ||
            event.reason == DisconnectReason.disconnected) {
          _status = AppConnectionStatus.disconnected;
          _errorMessage = null;
        } else {
          _status = AppConnectionStatus.error;
          _errorMessage = _formatDisconnectReason(event.reason);
        }

        _safeNotifyListeners();
      })
      ..on<RoomReconnectingEvent>((_) {
        _status = AppConnectionStatus.connecting;
        _safeNotifyListeners();
      })
      ..on<RoomResumingEvent>((_) {
        _status = AppConnectionStatus.connecting;
        _safeNotifyListeners();
      })
      ..on<RoomReconnectedEvent>((_) {
        _status = AppConnectionStatus.connected;
        _errorMessage = null;
        _syncRemoteParticipants();
        _safeNotifyListeners();
      });
  }

  Future<void> _detachRoom() async {
    final room = _liveKitService.room;
    if (room != null) {
      room.removeListener(_handleRoomChanged);
    }

    final roomEvents = _roomEvents;
    _roomEvents = null;

    if (roomEvents != null) {
      await roomEvents.dispose();
    }
  }

  void _handleRoomChanged() {
    _syncRemoteParticipants();
    _safeNotifyListeners();
  }

  void _syncRemoteParticipants() {
    final room = _liveKitService.room;
    if (room == null) {
      _remoteParticipantNames = const <String>[];
      return;
    }

    final names =
        room.remoteParticipants.values
            .map(
              (participant) => participant.name.trim().isNotEmpty
                  ? participant.name.trim()
                  : participant.identity,
            )
            .toList()
          ..sort();

    _remoteParticipantNames = names;
  }

  Future<void> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      return;
    }

    throw _PermissionDeniedException(
      status.isPermanentlyDenied || status.isRestricted
          ? 'Microphone permission is blocked. Enable it in ${_permissionSettingsLabel()} to talk to Mila.'
          : 'Microphone permission is required to talk to Mila.',
    );
  }

  Future<void> _ensureCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      return;
    }

    throw _PermissionDeniedException(
      status.isPermanentlyDenied || status.isRestricted
          ? 'Camera permission is blocked. Enable it in ${_permissionSettingsLabel()} if you want video.'
          : 'Camera permission was not granted, so video will stay off.',
    );
  }

  Future<void> _handleConnectFailure(String message) async {
    await _detachRoom();
    await _liveKitService.disconnect();

    _status = AppConnectionStatus.error;
    _errorMessage = message;
    _isMicrophoneEnabled = false;
    _isCameraEnabled = false;
    _remoteParticipantNames = const <String>[];
    _safeNotifyListeners();
  }

  void _setBlockingError(String message) {
    _status = AppConnectionStatus.error;
    _errorMessage = message;
    _safeNotifyListeners();
  }

  String _resolveInitialBackendBaseUrl(String? storedUrl) {
    final bundled = AppConfig.defaultBackendBaseUrl.trim();
    if (bundled.isNotEmpty) {
      try {
        return _normalizeBackendBaseUrl(bundled);
      } on FormatException {
        // Fall back to stored value if the bundled default is malformed.
      }
    }

    final stored = storedUrl?.trim() ?? '';
    return stored;
  }

  String _normalizeBackendBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Backend URL cannot be empty.');
    }

    late final Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } on FormatException {
      throw const FormatException(
        'Enter a valid backend URL like https://my-domain.com.',
      );
    }

    if (!uri.hasScheme || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException(
        'Backend URL must start with http:// or https://.',
      );
    }

    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }

  CameraCaptureOptions _cameraCaptureOptions() {
    return CameraCaptureOptions(cameraPosition: _cameraPosition);
  }

  String _formatDisconnectReason(DisconnectReason? reason) {
    if (reason == null || reason == DisconnectReason.unknown) {
      return 'LiveKit disconnected unexpectedly.';
    }

    return 'LiveKit disconnected: ${reason.name}.';
  }

  String _permissionSettingsLabel() {
    if (kIsWeb) {
      return 'your browser site settings';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'iOS Settings';
      case TargetPlatform.android:
        return 'Android app settings';
      default:
        return 'system settings';
    }
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

class _PermissionDeniedException implements Exception {
  const _PermissionDeniedException(this.message);

  final String message;
}
