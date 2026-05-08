import 'package:livekit_client/livekit_client.dart';

class LiveKitServiceException implements Exception {
  const LiveKitServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LiveKitService {
  Room? _room;

  Room? get room => _room;

  Future<Room> connect({
    required String serverUrl,
    required String participantToken,
  }) async {
    await disconnect();

    final room = Room(
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
    );

    try {
      await room.prepareConnection(serverUrl, participantToken);
      await room.connect(
        serverUrl,
        participantToken,
        connectOptions: const ConnectOptions(autoSubscribe: true),
      );

      final localParticipant = room.localParticipant;
      if (localParticipant == null) {
        throw const LiveKitServiceException(
          'Connected to LiveKit, but no local participant is available.',
        );
      }

      await localParticipant.setMicrophoneEnabled(true);
      _room = room;
      return room;
    } on LiveKitServiceException {
      await _disposeRoom(room);
      rethrow;
    } catch (error) {
      await _disposeRoom(room);
      throw LiveKitServiceException('Could not connect to LiveKit: $error');
    }
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    final localParticipant = _requireRoom().localParticipant;
    if (localParticipant == null) {
      throw const LiveKitServiceException(
        'Microphone controls are unavailable because the local participant is missing.',
      );
    }

    try {
      await localParticipant.setMicrophoneEnabled(enabled);
    } catch (error) {
      final action = enabled ? 'enable' : 'disable';
      throw LiveKitServiceException('Could not $action the microphone: $error');
    }
  }

  Future<void> setCameraEnabled(
    bool enabled, {
    CameraCaptureOptions? cameraCaptureOptions,
  }) async {
    final localParticipant = _requireRoom().localParticipant;
    if (localParticipant == null) {
      throw const LiveKitServiceException(
        'Camera controls are unavailable because the local participant is missing.',
      );
    }

    try {
      await localParticipant.setCameraEnabled(
        enabled,
        cameraCaptureOptions: cameraCaptureOptions,
      );
    } catch (error) {
      final action = enabled ? 'enable' : 'disable';
      throw LiveKitServiceException('Could not $action the camera: $error');
    }
  }

  Future<void> setCameraPosition(CameraPosition position) async {
    final localParticipant = _requireRoom().localParticipant;
    if (localParticipant == null) {
      throw const LiveKitServiceException(
        'Camera controls are unavailable because the local participant is missing.',
      );
    }

    final publication = localParticipant.getTrackPublicationBySource(
      TrackSource.camera,
    );
    final track = publication?.track;
    if (track is! LocalVideoTrack) {
      throw const LiveKitServiceException(
        'No active local camera track is available to switch.',
      );
    }

    try {
      await track.setCameraPosition(position);
    } catch (error) {
      throw LiveKitServiceException('Could not switch the camera: $error');
    }
  }

  Future<void> sendTextMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final localParticipant = _requireRoom().localParticipant;
    if (localParticipant == null) {
      throw const LiveKitServiceException(
        'Text message controls are unavailable because the local participant is missing.',
      );
    }

    try {
      await localParticipant.sendText(
        trimmed,
        options: SendTextOptions(topic: 'lk.chat'),
      );
    } catch (error) {
      throw LiveKitServiceException('Could not send text to Mila: $error');
    }
  }

  Future<void> disconnect() async {
    final room = _room;
    _room = null;

    if (room == null) {
      return;
    }

    try {
      if (room.connectionState != ConnectionState.disconnected) {
        await room.disconnect();
      }
    } catch (_) {
      // Ignore disconnect failures; disposal is the important cleanup path.
    }

    await _disposeRoom(room);
  }

  Room _requireRoom() {
    final room = _room;
    if (room == null) {
      throw const LiveKitServiceException('LiveKit is not connected.');
    }

    return room;
  }

  Future<void> _disposeRoom(Room room) async {
    try {
      await room.dispose();
    } catch (_) {
      // Ignore disposal failures during cleanup.
    }
  }
}
