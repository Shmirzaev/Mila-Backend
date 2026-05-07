import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../state/app_state.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showDetailsPanel = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      unawaited(context.read<AppState>().maybeAutoConnectOnLaunch());
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final palette = Theme.of(context).extension<MilaPalette>()!;
    final inCall = appState.isConnected || appState.isConnecting;

    return Scaffold(
      backgroundColor: inCall
          ? palette.darkBackground
          : palette.lightBackground,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: inCall
              ? _CallExperience(
                  key: const ValueKey<String>('call'),
                  appState: appState,
                  showDetailsPanel: _showDetailsPanel,
                  onDisconnect: context.read<AppState>().disconnect,
                  onOpenSettings: () => _openSettings(context),
                  onToggleCamera: context.read<AppState>().toggleCamera,
                  onToggleDetails: () {
                    setState(() {
                      _showDetailsPanel = !_showDetailsPanel;
                    });
                  },
                  onToggleMicrophone: context.read<AppState>().toggleMicrophone,
                )
              : _ConnectExperience(
                  key: const ValueKey<String>('connect'),
                  appState: appState,
                  onConnect: context.read<AppState>().connect,
                  onOpenSettings: () => _openSettings(context),
                ),
        ),
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }
}

class _ConnectExperience extends StatelessWidget {
  const _ConnectExperience({
    required this.appState,
    required this.onConnect,
    required this.onOpenSettings,
    super.key,
  });

  final AppState appState;
  final Future<void> Function() onConnect;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<MilaPalette>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;

        return Stack(
          children: <Widget>[
            Positioned(
              top: 18,
              left: compact ? 18 : 28,
              right: compact ? 18 : 28,
              child: Row(
                children: <Widget>[
                  _ToneChip(
                    label: 'MILA ${appState.platformLabel.toUpperCase()}',
                    dark: false,
                  ),
                  const Spacer(),
                  _StatusChip(
                    label: appState.statusLabel.toUpperCase(),
                    color: palette.blue500,
                    dark: false,
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: onOpenSettings,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF111111),
                    ),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 20 : 28,
                  84,
                  compact ? 20 : 28,
                  28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: palette.lightOutline),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x0C111111),
                              blurRadius: 40,
                              offset: Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 22 : 36,
                            vertical: compact ? 28 : 40,
                          ),
                          child: Column(
                            children: <Widget>[
                              _MilaAppMark(size: compact ? 108 : 126),
                              const SizedBox(height: 26),
                              Text(
                                'Start a call to speak with MILA.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontSize: compact ? 34 : 42,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'This Flutter client now follows the same voice-assistant UI direction as the Android reference: a minimal connect screen, a dark assistant stage, and a floating call control bar.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: const Color(0xFF4C4C48),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: <Widget>[
                                  _InfoPill(
                                    icon: Icons.public,
                                    label: 'WEB',
                                    dark: false,
                                  ),
                                  _InfoPill(
                                    icon: Icons.android,
                                    label: 'ANDROID',
                                    dark: false,
                                  ),
                                  _InfoPill(
                                    icon: Icons.phone_iphone,
                                    label: 'IOS',
                                    dark: false,
                                  ),
                                ],
                              ),
                              if (appState.errorMessage != null) ...<Widget>[
                                const SizedBox(height: 18),
                                _ErrorBanner(message: appState.errorMessage!),
                              ],
                              const SizedBox(height: 26),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 340,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: appState.isConnecting
                                        ? null
                                        : onConnect,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        if (appState.isConnecting) ...<Widget>[
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.1,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                        Text(
                                          appState.isConnecting
                                              ? 'CONNECTING'
                                              : 'TALK TO MILA',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextButton.icon(
                                onPressed: onOpenSettings,
                                icon: const Icon(Icons.tune),
                                label: const Text('Configure Backend URL'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          _ConnectInfoCard(
                            title: 'Saved backend',
                            width: compact ? double.infinity : 410,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  appState.hasBackendBaseUrl
                                      ? appState.backendBaseUrl
                                      : 'No backend URL saved yet. Open Settings and enter your token server base URL.',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontFamily: appState.hasBackendBaseUrl
                                        ? 'monospace'
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: <Widget>[
                                    _InfoPill(
                                      icon: Icons.link,
                                      label: appState.participantSource,
                                      dark: false,
                                    ),
                                    _InfoPill(
                                      icon: Icons.person_outline,
                                      label: appState.participantIdentity,
                                      dark: false,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _ConnectInfoCard(
                            title: 'Development URLs',
                            width: compact ? double.infinity : 410,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const <Widget>[
                                _HintLine(
                                  title: 'Web on same machine',
                                  value: 'http://127.0.0.1:8000',
                                ),
                                _HintLine(
                                  title: 'Android emulator',
                                  value: 'http://10.0.2.2:8000',
                                ),
                                _HintLine(
                                  title: 'Phone on Wi-Fi',
                                  value: 'http://YOUR_PC_LAN_IP:8000',
                                ),
                                _HintLine(
                                  title: 'Production',
                                  value: 'https://my-domain.com',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CallExperience extends StatelessWidget {
  const _CallExperience({
    required this.appState,
    required this.showDetailsPanel,
    required this.onDisconnect,
    required this.onOpenSettings,
    required this.onToggleCamera,
    required this.onToggleDetails,
    required this.onToggleMicrophone,
    super.key,
  });

  final AppState appState;
  final bool showDetailsPanel;
  final Future<void> Function() onDisconnect;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onToggleCamera;
  final VoidCallback onToggleDetails;
  final Future<void> Function() onToggleMicrophone;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<MilaPalette>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;
        final outerPadding = constraints.maxWidth < 720 ? 16.0 : 24.0;

        return Stack(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(outerPadding, 18, outerPadding, 18),
              child: Column(
                children: <Widget>[
                  _CallHeader(
                    appState: appState,
                    onOpenSettings: onOpenSettings,
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: wide
                        ? Row(
                            children: <Widget>[
                              Expanded(
                                flex: showDetailsPanel ? 7 : 10,
                                child: _AssistantStage(appState: appState),
                              ),
                              if (showDetailsPanel) ...<Widget>[
                                const SizedBox(width: 18),
                                Expanded(
                                  flex: 3,
                                  child: _DetailsPanel(appState: appState),
                                ),
                              ],
                            ],
                          )
                        : _AssistantStage(appState: appState),
                  ),
                  const SizedBox(height: 102),
                ],
              ),
            ),
            if (!wide && showDetailsPanel)
              Positioned(
                left: outerPadding,
                right: outerPadding,
                bottom: 100,
                child: _DetailsPanel(appState: appState, compact: true),
              ),
            Positioned(
              left: outerPadding,
              right: outerPadding,
              bottom: 18,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: _ControlDock(
                    appState: appState,
                    onDisconnect: onDisconnect,
                    onOpenSettings: onOpenSettings,
                    onToggleCamera: onToggleCamera,
                    onToggleDetails: onToggleDetails,
                    onToggleMicrophone: onToggleMicrophone,
                    showDetailsPanel: showDetailsPanel,
                    palette: palette,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CallHeader extends StatelessWidget {
  const _CallHeader({required this.appState, required this.onOpenSettings});

  final AppState appState;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<MilaPalette>()!;

    return Row(
      children: <Widget>[
        const _ToneChip(label: 'MILA LIVE', dark: true),
        const SizedBox(width: 12),
        _StatusChip(
          label: appState.statusLabel.toUpperCase(),
          color: appState.isConnected ? palette.signalActive : palette.blue500,
          dark: true,
        ),
        const SizedBox(width: 12),
        _StatusChip(
          label: appState.remoteParticipantNames.isEmpty
              ? 'WAITING FOR AGENT'
              : appState.remoteParticipantNames.join(', ').toUpperCase(),
          color: Colors.white70,
          dark: true,
          subtle: true,
        ),
        const Spacer(),
        IconButton(
          onPressed: onOpenSettings,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

class _AssistantStage extends StatelessWidget {
  const _AssistantStage({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<MilaPalette>()!;
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.darkSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.darkOutline),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 0.9,
                  colors: <Color>[
                    palette.blue500.withValues(alpha: 0.08),
                    palette.darkBackground,
                    palette.darkSurface,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _ToneChip(
                      label: appState.isMicrophoneEnabled
                          ? 'MIC HOT'
                          : 'MIC MUTED',
                      dark: true,
                    ),
                    const Spacer(),
                    if (appState.isCameraEnabled)
                      const _ToneChip(label: 'VIDEO ON', dark: true),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _AssistantVisualizer(active: true, palette: palette),
                      const SizedBox(height: 24),
                      Text(
                        appState.isConnecting
                            ? 'Connecting to Mila...'
                            : 'Mila is ready to listen.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 30,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        appState.isConnecting
                            ? 'Waiting for LiveKit to finish connecting and publish your microphone.'
                            : 'Assistant audio will play through LiveKit as soon as the room is active.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          if (appState.isCameraEnabled)
            const Positioned(
              right: 18,
              bottom: 18,
              child: _CameraPreviewCard(),
            ),
          if (appState.errorMessage != null)
            Positioned(
              left: 18,
              right: 18,
              top: 76,
              child: _ErrorBanner(message: appState.errorMessage!, dark: true),
            ),
        ],
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({required this.appState, this.compact = false});

  final AppState appState;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<MilaPalette>()!;
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.darkSurface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.darkOutline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Agent Panel',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                const _ToneChip(label: 'DETAILS', dark: true),
              ],
            ),
            const SizedBox(height: 16),
            _PanelRow(label: 'Participant', value: appState.participantName),
            _PanelRow(label: 'Identity', value: appState.participantIdentity),
            _PanelRow(label: 'Source', value: appState.participantSource),
            _PanelRow(
              label: 'Backend',
              value: appState.hasBackendBaseUrl
                  ? appState.backendBaseUrl
                  : 'Not configured',
              multiline: true,
            ),
            const SizedBox(height: 14),
            Text(
              'Remote participants',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (appState.remoteParticipantNames.isEmpty)
              Text(
                'Waiting for Mila to join the room.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: appState.remoteParticipantNames
                    .map(
                      (name) => _InfoPill(
                        icon: Icons.graphic_eq,
                        label: name,
                        dark: true,
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 18),
            Text(
              'Quick backend URLs',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const _PanelHint(
              title: 'Android emulator',
              value: 'http://10.0.2.2:8000',
            ),
            const _PanelHint(
              title: 'Phone on Wi-Fi',
              value: 'http://YOUR_PC_LAN_IP:8000',
            ),
            const _PanelHint(
              title: 'Production',
              value: 'https://my-domain.com',
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlDock extends StatelessWidget {
  const _ControlDock({
    required this.appState,
    required this.onDisconnect,
    required this.onOpenSettings,
    required this.onToggleCamera,
    required this.onToggleDetails,
    required this.onToggleMicrophone,
    required this.showDetailsPanel,
    required this.palette,
  });

  final AppState appState;
  final Future<void> Function() onDisconnect;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onToggleCamera;
  final VoidCallback onToggleDetails;
  final Future<void> Function() onToggleMicrophone;
  final bool showDetailsPanel;
  final MilaPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.darkBackground.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.darkOutline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _DockMicButton(
              active: appState.isMicrophoneEnabled,
              onPressed: onToggleMicrophone,
            ),
            const SizedBox(width: 8),
            _DockButton(
              icon: appState.isCameraEnabled
                  ? Icons.videocam
                  : Icons.videocam_off,
              active: appState.isCameraEnabled,
              onPressed: onToggleCamera,
            ),
            const SizedBox(width: 8),
            _DockButton(
              icon: Icons.chat_bubble_outline,
              active: showDetailsPanel,
              onPressed: onToggleDetails,
            ),
            const SizedBox(width: 8),
            _DockButton(
              icon: Icons.settings_outlined,
              active: false,
              onPressed: onOpenSettings,
            ),
            const SizedBox(width: 8),
            _DockButton(
              icon: Icons.call_end,
              active: false,
              destructive: true,
              onPressed: onDisconnect,
            ),
          ],
        ),
      ),
    );
  }
}

class _DockMicButton extends StatefulWidget {
  const _DockMicButton({required this.active, required this.onPressed});

  final bool active;
  final Future<void> Function() onPressed;

  @override
  State<_DockMicButton> createState() => _DockMicButtonState();
}

class _DockMicButtonState extends State<_DockMicButton> {
  double _phase = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _DockMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    if (!widget.active) {
      return;
    }

    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _phase += 0.42;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _DockShell(
      active: widget.active,
      onPressed: widget.onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(widget.active ? Icons.mic : Icons.mic_off, color: Colors.white),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: widget.active ? 1 : 0,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 16,
                height: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List<Widget>.generate(3, (index) {
                    final factor = (0.35 + 0.5 * math.sin(_phase + index * 0.8))
                        .clamp(0.18, 0.94);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 3,
                      height: 20 * factor,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.active,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final bool active;
  final bool destructive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _DockShell(
      active: active,
      onPressed: onPressed,
      child: Icon(
        icon,
        color: destructive
            ? Colors.redAccent
            : active
            ? Colors.white
            : Colors.white.withValues(alpha: 0.78),
      ),
    );
  }
}

class _DockShell extends StatelessWidget {
  const _DockShell({
    required this.active,
    required this.onPressed,
    required this.child,
  });

  final bool active;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: child,
        ),
      ),
    );
  }
}

class _AssistantVisualizer extends StatefulWidget {
  const _AssistantVisualizer({required this.active, required this.palette});

  final bool active;
  final MilaPalette palette;

  @override
  State<_AssistantVisualizer> createState() => _AssistantVisualizerState();
}

class _AssistantVisualizerState extends State<_AssistantVisualizer> {
  late final Timer _timer;
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 140), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _phase += 0.42;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseHeights = <double>[0.30, 0.86, 0.54, 0.72, 0.38];
    final glowOpacity = widget.active ? 0.18 : 0.07;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: 340,
      height: 340,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            widget.palette.blue500.withValues(alpha: glowOpacity),
            widget.palette.darkBackground,
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: widget.palette.blue500.withValues(alpha: glowOpacity),
            blurRadius: 48,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: 190,
          height: 160,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List<Widget>.generate(baseHeights.length, (index) {
              final animatedFactor = widget.active
                  ? (baseHeights[index] +
                            0.11 * math.sin(_phase + index * 0.75))
                        .clamp(0.20, 0.92)
                  : baseHeights[index];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Align(
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: index == 1 || index == 3 ? 26 : 18,
                    height: 160 * animatedFactor,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _CameraPreviewCard extends StatelessWidget {
  const _CameraPreviewCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SizedBox(
        width: 156,
        height: 114,
        child: Stack(
          children: <Widget>[
            const Center(child: _MilaAppMark(size: 58)),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cameraswitch,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectInfoCard extends StatelessWidget {
  const _ConnectInfoCard({
    required this.title,
    required this.child,
    required this.width,
  });

  final String title;
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<MilaPalette>()!;

    return SizedBox(
      width: width.isFinite ? width : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFBFBF8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.lightOutline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _MilaAppMark extends StatelessWidget {
  const _MilaAppMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.26),
      child: Image.asset(
        'assets/ui/mila_mark.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.dark,
    this.subtle = false,
  });

  final String label;
  final Color color;
  final bool dark;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final background = dark
        ? Colors.white.withValues(alpha: subtle ? 0.06 : 0.08)
        : color.withValues(alpha: 0.10);
    final foreground = dark ? (subtle ? Colors.white70 : color) : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _ToneChip extends StatelessWidget {
  const _ToneChip({required this.label, required this.dark});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF0F0EC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: dark ? Colors.white70 : const Color(0xFF232323),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.dark,
  });

  final IconData icon;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final background = dark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF0F0EC);
    final foreground = dark ? Colors.white : const Color(0xFF242424);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: foreground.withValues(alpha: 0.9)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: multiline ? null : 1,
            overflow: multiline ? TextOverflow.visible : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontFamily: label == 'Identity' ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHint extends StatelessWidget {
  const _PanelHint({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _HintLine extends StatelessWidget {
  const _HintLine({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF232323),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.dark = false});

  final String message;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? const Color(0x33FF5A5A) : const Color(0xFFFFECE9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark ? const Color(0x66FF6B6B) : const Color(0xFFFFD0C9),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.error_outline,
            color: dark ? Colors.white : const Color(0xFF9C2F20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: dark ? Colors.white : const Color(0xFF6A2117),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
