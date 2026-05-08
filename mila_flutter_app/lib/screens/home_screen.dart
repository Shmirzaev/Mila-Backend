import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/employee_record.dart';
import '../state/app_state.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showEmployeePanel = false;

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
    if (kIsWeb) {
      return _WebLiveScreen(
        appState: appState,
        onConnect: context.read<AppState>().connect,
        onDisconnect: context.read<AppState>().disconnect,
        onToggleMicrophone: context.read<AppState>().toggleMicrophone,
        onToggleCamera: context.read<AppState>().toggleCamera,
        onOpenSettings: () => _openSettings(context),
      );
    }

    final palette = Theme.of(context).extension<MilaPalette>()!;
    final inCall = appState.isConnected || appState.isConnecting;

    return Scaffold(
      backgroundColor: inCall
          ? palette.darkBackground
          : palette.lightBackground,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: inCall
              ? _CallScreen(
                  key: const ValueKey<String>('call-screen'),
                  appState: appState,
                  showEmployeePanel: _showEmployeePanel,
                  onConnect: context.read<AppState>().connect,
                  onDisconnect: context.read<AppState>().disconnect,
                  onOpenSettings: () => _openSettings(context),
                  onRefreshEmployees: context
                      .read<AppState>()
                      .refreshEmployeeDirectory,
                  onToggleCamera: context.read<AppState>().toggleCamera,
                  onToggleEmployeePanel: () {
                    setState(() {
                      _showEmployeePanel = !_showEmployeePanel;
                    });
                  },
                  onToggleMicrophone: context.read<AppState>().toggleMicrophone,
                )
              : _ConnectScreen(
                  key: const ValueKey<String>('connect-screen'),
                  appState: appState,
                  onConnect: context.read<AppState>().connect,
                  onDisconnect: context.read<AppState>().disconnect,
                  onOpenSettings: () => _openSettings(context),
                  onRefreshEmployees: context
                      .read<AppState>()
                      .refreshEmployeeDirectory,
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

class _WebLiveScreen extends StatefulWidget {
  const _WebLiveScreen({
    required this.appState,
    required this.onConnect,
    required this.onDisconnect,
    required this.onToggleMicrophone,
    required this.onToggleCamera,
    required this.onOpenSettings,
  });

  final AppState appState;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onToggleMicrophone;
  final Future<void> Function() onToggleCamera;
  final VoidCallback onOpenSettings;

  @override
  State<_WebLiveScreen> createState() => _WebLiveScreenState();
}

class _WebLiveScreenState extends State<_WebLiveScreen> {
  final TextEditingController _composer = TextEditingController();
  final FocusNode _composerFocus = FocusNode();
  final ScrollController _messageScroll = ScrollController();
  bool _darkMode = true;
  bool _isSendingText = false;
  final List<_WebChatMessage> _messages = <_WebChatMessage>[
    _WebChatMessage(
      fromUser: false,
      text: '\u0417\u0434\u0440\u0430\u0432\u0441\u0442\u0432\u0443\u0439\u0442\u0435, \u044f Mila. \u0413\u043e\u0432\u043e\u0440\u0438\u0442\u0435 \u0438\u043b\u0438 \u043d\u0430\u043f\u0438\u0448\u0438\u0442\u0435 \u0441\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435, \u0447\u0442\u043e\u0431\u044b \u043d\u0430\u0447\u0430\u0442\u044c.',
    ),
  ];

  @override
  void dispose() {
    _composer.dispose();
    _composerFocus.dispose();
    _messageScroll.dispose();
    super.dispose();
  }

  Future<void> _handleConnectTap() async {
    if (widget.appState.isConnecting) {
      return;
    }

    if (widget.appState.isConnected) {
      await widget.onDisconnect();
      return;
    }

    await widget.onConnect();
  }

  void _queueScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageScroll.hasClients) {
        return;
      }

      _messageScroll.animateTo(
        _messageScroll.position.maxScrollExtent + 42,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _sendText([String? predefined]) async {
    final value = (predefined ?? _composer.text).trim();
    if (value.isEmpty || _isSendingText) {
      return;
    }
    if (!widget.appState.isConnected) {
      setState(() {
        _messages.add(
          const _WebChatMessage(
            fromUser: false,
            text: '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u043d\u0430\u0436\u043c\u0438\u0442\u0435 \u0421\u0442\u0430\u0440\u0442 \u0438 \u043f\u043e\u0434\u043a\u043b\u044e\u0447\u0438\u0442\u0435 Mila.',
          ),
        );
      });
      _queueScrollToBottom();
      return;
    }

    setState(() {
      _isSendingText = true;
      _messages.add(_WebChatMessage(fromUser: true, text: value));
      _composer.clear();
    });
    _queueScrollToBottom();
    try {
      await widget.appState.sendTextMessage(value);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _WebChatMessage(
            fromUser: false,
            text: '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043e\u0442\u043f\u0440\u0430\u0432\u0438\u0442\u044c: $error',
          ),
        );
      });
      _queueScrollToBottom();
    } finally {
      if (mounted) {
        setState(() {
          _isSendingText = false;
        });
      }
      _composerFocus.requestFocus();
    }
  }

  Future<void> _pickAttachment(_WebAttachmentKind kind) async {
    final prefix = kind == _WebAttachmentKind.image
        ? '\u0418\u0437\u043e\u0431\u0440\u0430\u0436\u0435\u043d\u0438\u0435'
        : '\u0424\u0430\u0439\u043b';

    setState(() {
      _messages.add(
        _WebChatMessage(
          fromUser: true,
          text: '[$prefix] \u0434\u043e\u0431\u0430\u0432\u043b\u0435\u043d\u043e',
        ),
      );
      _messages.add(
        const _WebChatMessage(
          fromUser: false,
          text: '\u0412\u043b\u043e\u0436\u0435\u043d\u0438\u0435 \u043e\u0442\u043c\u0435\u0447\u0435\u043d\u043e. \u041e\u0442\u043f\u0440\u0430\u0432\u044c\u0442\u0435 \u0441\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435 \u0441 \u043e\u043f\u0438\u0441\u0430\u043d\u0438\u0435\u043c \u0444\u0430\u0439\u043b\u0430.',
        ),
      );
    });
    _queueScrollToBottom();
  }

  Future<void> _showAttachChooser() async {
    final choice = await showModalBottomSheet<_WebAttachmentKind>(
      context: context,
      backgroundColor: _surface(),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u0438\u0437\u043e\u0431\u0440\u0430\u0436\u0435\u043d\u0438\u0435'),
                onTap: () => Navigator.of(context).pop(_WebAttachmentKind.image),
              ),
              ListTile(
                leading: const Icon(Icons.attach_file_outlined),
                title: const Text('\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u0444\u0430\u0439\u043b'),
                onTap: () => Navigator.of(context).pop(_WebAttachmentKind.file),
              ),
            ],
          ),
        );
      },
    );

    if (choice == null) {
      return;
    }

    await _pickAttachment(choice);
  }

  Color _bgColor() => _darkMode ? const Color(0xFF110E07) : const Color(0xFFFAF3E8);
  Color _textColor() => _darkMode ? const Color(0xFFF0E4CC) : const Color(0xFF1E1108);
  Color _mutedColor() => _darkMode ? const Color(0xFFC4A070) : const Color(0xFF7A5535);
  Color _accent() => _darkMode ? const Color(0xFFC48E48) : const Color(0xFFB5712A);
  Color _accent2() => _darkMode ? const Color(0xFFD4A870) : const Color(0xFFD4955A);
  Color _surface() => _darkMode
      ? const Color(0xFF1C1408).withValues(alpha: 0.86)
      : Colors.white.withValues(alpha: 0.82);
  Color _border() => _darkMode
      ? const Color(0xFFC48E48).withValues(alpha: 0.18)
      : const Color(0xFFB4783C).withValues(alpha: 0.24);

  String _connectionLabel() {
    switch (widget.appState.status) {
      case AppConnectionStatus.connected:
        return '\u041f\u043e\u0434\u043a\u043b\u044e\u0447\u0435\u043d\u043e \u043a MILA';
      case AppConnectionStatus.connecting:
        return '\u041f\u043e\u0434\u043a\u043b\u044e\u0447\u0435\u043d\u0438\u0435...';
      case AppConnectionStatus.error:
        return '\u041e\u0448\u0438\u0431\u043a\u0430 \u043f\u043e\u0434\u043a\u043b\u044e\u0447\u0435\u043d\u0438\u044f';
      case AppConnectionStatus.disconnected:
        return '\u041e\u0442\u043a\u043b\u044e\u0447\u0435\u043d\u043e';
    }
  }

  Color _connectionDotColor() {
    switch (widget.appState.status) {
      case AppConnectionStatus.connected:
        return const Color(0xFF4CAF7D);
      case AppConnectionStatus.connecting:
        return const Color(0xFFE8A857);
      case AppConnectionStatus.error:
        return const Color(0xFFE74C3C);
      case AppConnectionStatus.disconnected:
        return const Color(0xFF8A8A8A);
    }
  }

  String _agentStateLabel() {
    if (widget.appState.isConnecting) {
      return '\u041f\u043e\u0434\u043a\u043b\u044e\u0447\u0435\u043d\u0438\u0435 \u043a Mila...';
    }
    if (widget.appState.remoteParticipantNames.isNotEmpty) {
      return 'Mila \u0441\u043b\u0443\u0448\u0430\u0435\u0442.';
    }
    if (widget.appState.isConnected) {
      return '\u041e\u0436\u0438\u0434\u0430\u043d\u0438\u0435 \u043f\u043e\u0434\u043a\u043b\u044e\u0447\u0435\u043d\u0438\u044f Mila \u043a \u043a\u043e\u043c\u043d\u0430\u0442\u0435.';
    }
    return '\u041d\u0430\u0436\u043c\u0438\u0442\u0435 \u0421\u0442\u0430\u0440\u0442 \u0434\u043b\u044f \u043f\u043e\u0434\u043a\u043b\u044e\u0447\u0435\u043d\u0438\u044f \u043a Mila.';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = _textColor();
    final accent = _accent();
    final muted = _mutedColor();
    final surface = _surface();
    final border = _border();
    final connected = widget.appState.isConnected;
    final connecting = widget.appState.isConnecting;
    final micLabel = widget.appState.isMicrophoneEnabled
        ? '\u041c\u0418\u041a\u0420\u041e\u0424\u041e\u041d \u0412\u041a\u041b'
        : '\u041c\u0418\u041a\u0420\u041e\u0424\u041e\u041d \u0412\u042b\u041a\u041b';
    final staffLabel = widget.appState.hasEmployeeDirectory
        ? '${widget.appState.employeeDirectory.length} \u0421\u041e\u0422\u0420\u0423\u0414\u041d\u0418\u041a\u041e\u0412'
        : '\u0421\u0418\u041d\u0425\u0420. \u0428\u0422\u0410\u0422\u0410';

    return Scaffold(
      backgroundColor: _bgColor(),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 20,
              left: 50,
              child: _WebBackgroundOrb(
                size: 360,
                color: accent.withValues(alpha: _darkMode ? 0.16 : 0.20),
              ),
            ),
            Positioned(
              right: 40,
              bottom: 40,
              child: _WebBackgroundOrb(
                size: 260,
                color: _accent2().withValues(alpha: _darkMode ? 0.12 : 0.18),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '\u041f\u0415\u0420\u0421\u041e\u041d\u0410\u041b\u042c\u041d\u042b\u0419 \u0418\u0418 - MILANA PREMIUM',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 10,
                                    letterSpacing: 2.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'MILA',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 48,
                                    height: 0.96,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _WebIconButton(
                            icon: widget.appState.isCameraEnabled
                                ? Icons.videocam
                                : Icons.videocam_off,
                            active: widget.appState.isCameraEnabled,
                            onPressed: widget.onToggleCamera,
                          ),
                          const SizedBox(width: 8),
                          _WebIconButton(
                            icon: _darkMode ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                            onPressed: () {
                              setState(() {
                                _darkMode = !_darkMode;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          _WebPowerButton(
                            active: connected,
                            onPressed: _handleConnectTap,
                            connecting: connecting,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _connectionDotColor(),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _connectionLabel().toUpperCase(),
                              style: TextStyle(
                                color: muted,
                                fontSize: 11,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.appState.errorMessage != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFFE74C3C).withValues(alpha: 0.16),
                            border: Border.all(
                              color: const Color(0xFFE74C3C).withValues(alpha: 0.34),
                            ),
                          ),
                          child: Text(
                            widget.appState.errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFF9B8AF),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            if (!connected && !connecting) {
                              unawaited(widget.onConnect());
                            }
                          },
                          child: _WebVoiceOrb(
                            active: connected || connecting,
                            accent: accent,
                            accentSoft: _accent2(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _agentStateLabel(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _WebChip(
                            label: micLabel,
                            onTap: widget.onToggleMicrophone,
                            color: accent,
                            dark: _darkMode,
                          ),
                          _WebChip(
                            label: staffLabel,
                            onTap: widget.appState.hasBackendBaseUrl
                                ? widget.appState.refreshEmployeeDirectory
                                : widget.onOpenSettings,
                            color: accent,
                            dark: _darkMode,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          children: <Widget>[
                            SizedBox(
                              height: 224,
                              child: ListView.builder(
                                controller: _messageScroll,
                                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final message = _messages[index];
                                  final bubbleColor = message.fromUser
                                      ? LinearGradient(
                                          colors: <Color>[
                                            _accent2(),
                                            accent,
                                          ],
                                        )
                                      : null;

                                  return Align(
                                    alignment: message.fromUser
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                      constraints: const BoxConstraints(maxWidth: 410),
                                      decoration: BoxDecoration(
                                        gradient: bubbleColor,
                                        color: bubbleColor == null
                                            ? (_darkMode
                                                  ? Colors.white.withValues(alpha: 0.05)
                                                  : Colors.white)
                                            : null,
                                        borderRadius: BorderRadius.circular(12),
                                        border: message.fromUser
                                            ? null
                                            : Border.all(color: border),
                                      ),
                                      child: Text(
                                        message.text,
                                        style: TextStyle(
                                          color: message.fromUser
                                              ? const Color(0xFFFFF8EE)
                                              : textColor,
                                          fontSize: 13,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Container(height: 1, color: border),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                              child: Row(
                                children: <Widget>[
                                  _WebInputIconButton(
                                    icon: Icons.attach_file_outlined,
                                    onTap: _showAttachChooser,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: TextField(
                                      controller: _composer,
                                      focusNode: _composerFocus,
                                      onChanged: (_) {
                                        setState(() {});
                                      },
                                      textInputAction: TextInputAction.send,
                                      cursorColor: const Color(0xFFB5712A),
                                      keyboardType: TextInputType.text,
                                      onSubmitted: (_) {
                                        unawaited(_sendText());
                                      },
                                      style: const TextStyle(
                                        color: Color(0xFF2A1D0E),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '\u0412\u0432\u0435\u0434\u0438\u0442\u0435 \u0441\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435...',
                                        hintStyle: const TextStyle(
                                          color: Color(0xFF9A805F),
                                          fontSize: 14,
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF7F6F4),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed:
                                        (!connected ||
                                            _isSendingText ||
                                            _composer.text.trim().isEmpty)
                                        ? null
                                        : () {
                                            unawaited(_sendText());
                                          },
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          (!connected ||
                                              _isSendingText ||
                                              _composer.text.trim().isEmpty)
                                          ? accent.withValues(alpha: 0.34)
                                          : accent,
                                      foregroundColor: const Color(0xFFFFF8EE),
                                      disabledForegroundColor: const Color(0xFFFFF8EE),
                                      fixedSize: const Size(34, 34),
                                    ),
                                    icon: _isSendingText
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Color(0xFFFFF8EE),
                                              ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.send_rounded,
                                            size: 16,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'MILA - Milana Premium - \u0420\u0430\u0431\u043e\u0442\u0430\u0435\u0442 \u043d\u0430 LiveKit',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: muted.withValues(alpha: 0.8),
                          fontSize: 10,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebChatMessage {
  const _WebChatMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}

enum _WebAttachmentKind { image, file }

class _WebBackgroundOrb extends StatelessWidget {
  const _WebBackgroundOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _WebVoiceOrb extends StatefulWidget {
  const _WebVoiceOrb({
    required this.active,
    required this.accent,
    required this.accentSoft,
  });

  final bool active;
  final Color accent;
  final Color accentSoft;

  @override
  State<_WebVoiceOrb> createState() => _WebVoiceOrbState();
}

class _WebVoiceOrbState extends State<_WebVoiceOrb> {
  late final Timer _timer;
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _phase += 0.35;
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
    final rippleOpacity = widget.active ? 0.34 : 0.08;
    final bars = <double>[0.36, 0.82, 0.52, 0.72, 0.40];

    return SizedBox(
      width: 164,
      height: 164,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: widget.active ? 140 : 124,
            height: widget.active ? 140 : 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.accent.withValues(alpha: rippleOpacity),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: widget.active ? 112 : 104,
            height: widget.active ? 112 : 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[widget.accentSoft, widget.accent],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: widget.accent.withValues(alpha: widget.active ? 0.44 : 0.18),
                  blurRadius: widget.active ? 36 : 20,
                  spreadRadius: widget.active ? 2 : 0,
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                width: 56,
                height: 42,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List<Widget>.generate(bars.length, (index) {
                    final factor = widget.active
                        ? (bars[index] + 0.11 * math.sin(_phase + index * 0.75))
                            .clamp(0.24, 0.90)
                        : bars[index];
                    return Container(
                      width: index == 1 || index == 3 ? 8 : 6,
                      height: 42 * factor,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8EE),
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

class _WebIconButton extends StatelessWidget {
  const _WebIconButton({
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: active
            ? const Color(0xFFC48E48)
            : const Color(0xFFC48E48).withValues(alpha: 0.12),
        foregroundColor: active ? const Color(0xFFFFF8EE) : const Color(0xFFC48E48),
        side: BorderSide(
          color: active
              ? const Color(0xFFC48E48)
              : const Color(0xFFC48E48).withValues(alpha: 0.24),
        ),
        fixedSize: const Size(38, 38),
      ),
      icon: Icon(icon, size: 16),
    );
  }
}

class _WebPowerButton extends StatelessWidget {
  const _WebPowerButton({
    required this.active,
    required this.connecting,
    required this.onPressed,
  });

  final bool active;
  final bool connecting;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => unawaited(onPressed()),
      style: IconButton.styleFrom(
        backgroundColor: active
            ? const Color(0xFFC48E48)
            : const Color(0xFFC48E48).withValues(alpha: 0.12),
        foregroundColor: active ? const Color(0xFFFFF8EE) : const Color(0xFFC48E48),
        side: BorderSide(
          color: active
              ? const Color(0xFFC48E48)
              : const Color(0xFFC48E48).withValues(alpha: 0.24),
        ),
        fixedSize: const Size(42, 42),
      ),
      icon: connecting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFFFFF8EE),
                ),
              ),
            )
          : Icon(
              Icons.power_settings_new,
              size: 18,
              color: active
                  ? const Color(0xFFFFF8EE)
                  : const Color(0xFFC48E48),
            ),
      tooltip: active ? '\u041e\u0442\u043a\u043b\u044e\u0447\u0438\u0442\u044c\u0441\u044f' : '\u041f\u043e\u0434\u043a\u043b\u044e\u0447\u0438\u0442\u044c\u0441\u044f',
    );
  }
}

class _WebInputIconButton extends StatelessWidget {
  const _WebInputIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => unawaited(onTap()),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFB5712A),
        side: const BorderSide(
          color: Color(0x33B5712A),
        ),
        fixedSize: const Size(34, 34),
      ),
      icon: Icon(icon, size: 16),
      tooltip: '\u0412\u043b\u043e\u0436\u0435\u043d\u0438\u0435',
    );
  }
}

class _WebChip extends StatelessWidget {
  const _WebChip({
    required this.label,
    required this.onTap,
    required this.color,
    required this.dark,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dark ? 0.09 : 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ConnectScreen extends StatelessWidget {
  const _ConnectScreen({
    required this.appState,
    required this.onConnect,
    required this.onDisconnect,
    required this.onOpenSettings,
    required this.onRefreshEmployees,
    super.key,
  });

  final AppState appState;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onRefreshEmployees;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<MilaPalette>()!;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;

        return Stack(
          children: <Widget>[
            Positioned(
              top: 18,
              left: compact ? 18 : 24,
              right: compact ? 18 : 24,
              child: Row(
                children: <Widget>[
                  const _ToneChip(label: 'MILA ANDROID', dark: false),
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
                  88,
                  compact ? 20 : 28,
                  28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: palette.lightOutline),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x0A111111),
                              blurRadius: 36,
                              offset: Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 24 : 36,
                            vertical: compact ? 30 : 40,
                          ),
                          child: Column(
                            children: <Widget>[
                              const _MilaAppMark(size: 112),
                              const SizedBox(height: 22),
                              Text(
                                'Start a call to speak with MILA.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontSize: compact ? 34 : 42,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Your LiveKit room is ready, your backend is bundled into the APK, and the employee directory is synced from the same server.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: const Color(0xFF4B4B49),
                                ),
                              ),
                              if (appState.errorMessage != null) ...<Widget>[
                                const SizedBox(height: 18),
                                _ErrorBanner(message: appState.errorMessage!),
                              ],
                              const SizedBox(height: 24),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 340,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: appState.isConnecting
                                        ? null
                                        : (appState.isConnected
                                            ? onDisconnect
                                            : onConnect),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        if (appState.isConnecting) ...<Widget>[
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
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
                                              : (appState.isConnected
                                                  ? 'END CALL'
                                                  : 'TALK TO MILA'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: <Widget>[
                                  _InfoPill(
                                    icon: Icons.link,
                                    label: appState.hasBackendBaseUrl
                                        ? 'BACKEND READY'
                                        : 'SET BACKEND',
                                    dark: false,
                                  ),
                                  _InfoPill(
                                    icon: Icons.groups_2_outlined,
                                    label: appState.hasEmployeeDirectory
                                        ? '${appState.employeeDirectory.length} EMPLOYEES'
                                        : 'STAFF SYNC',
                                    dark: false,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _EmployeeDirectoryPanel(
                        title: 'Employee Directory',
                        subtitle: appState.hasBackendBaseUrl
                            ? 'Synced from ${appState.backendBaseUrl}'
                            : 'Save a backend URL in Settings to load employees.',
                        appState: appState,
                        dark: false,
                        onRefresh: onRefreshEmployees,
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

class _CallScreen extends StatelessWidget {
  const _CallScreen({
    required this.appState,
    required this.showEmployeePanel,
    required this.onConnect,
    required this.onDisconnect,
    required this.onOpenSettings,
    required this.onRefreshEmployees,
    required this.onToggleCamera,
    required this.onToggleEmployeePanel,
    required this.onToggleMicrophone,
    super.key,
  });

  final AppState appState;
  final bool showEmployeePanel;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onRefreshEmployees;
  final Future<void> Function() onToggleCamera;
  final VoidCallback onToggleEmployeePanel;
  final Future<void> Function() onToggleMicrophone;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<MilaPalette>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;
        final padding = constraints.maxWidth < 760 ? 16.0 : 24.0;

        return Stack(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 18, padding, 18),
              child: Column(
                children: <Widget>[
                  _CallHeader(
                    appState: appState,
                    onConnect: onConnect,
                    onDisconnect: onDisconnect,
                    onOpenSettings: onOpenSettings,
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: wide
                        ? Row(
                            children: <Widget>[
                              Expanded(
                                flex: showEmployeePanel ? 7 : 10,
                                child: _AssistantStage(appState: appState),
                              ),
                              if (showEmployeePanel) ...<Widget>[
                                const SizedBox(width: 18),
                                Expanded(
                                  flex: 4,
                                  child: _EmployeeDirectoryPanel(
                                    title: 'Employee Directory',
                                    subtitle:
                                        'Search your company staff while you talk to Mila.',
                                    appState: appState,
                                    dark: true,
                                    onRefresh: onRefreshEmployees,
                                  ),
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
            if (!wide && showEmployeePanel)
              Positioned(
                left: padding,
                right: padding,
                top: 92,
                bottom: 102,
                child: _EmployeeDirectoryPanel(
                  title: 'Employee Directory',
                  subtitle:
                      'Tap a record to review names, roles, and Telegram usernames.',
                  appState: appState,
                  dark: true,
                  onRefresh: onRefreshEmployees,
                ),
              ),
            Positioned(
              left: padding,
              right: padding,
              bottom: 18,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: _ControlDock(
                    appState: appState,
                    onDisconnect: onDisconnect,
                    onOpenSettings: onOpenSettings,
                    onToggleCamera: onToggleCamera,
                    onToggleEmployeePanel: onToggleEmployeePanel,
                    onToggleMicrophone: onToggleMicrophone,
                    showEmployeePanel: showEmployeePanel,
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
  const _CallHeader({
    required this.appState,
    required this.onConnect,
    required this.onDisconnect,
    required this.onOpenSettings,
  });

  final AppState appState;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<MilaPalette>()!;

    return Row(
      children: <Widget>[
        if (kIsWeb)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'PERSONAL AI В· MILANA PREMIUM',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.blue500.withValues(alpha: 0.9),
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'MILA',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          )
        else
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
        if (kIsWeb) ...<Widget>[
          TextButton(
            onPressed: appState.isConnecting
                ? null
                : (appState.isConnected ? onDisconnect : onConnect),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: appState.isConnected
                  ? Colors.redAccent.withValues(alpha: 0.2)
                  : palette.blue500.withValues(alpha: 0.24),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              appState.isConnecting
                  ? 'CONNECTING'
                  : (appState.isConnected ? 'END' : 'START'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
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
    final agentReady = appState.remoteParticipantNames.isNotEmpty;
    final disconnected =
        appState.status == AppConnectionStatus.disconnected && !appState.isConnecting;
    final connecting = appState.status == AppConnectionStatus.connecting;

    final headline = disconnected
        ? 'Tap START to connect to MILA.'
        : connecting
            ? 'Connecting to Mila...'
            : (agentReady
                ? 'Mila is ready to listen.'
                : 'Waiting for Mila to join the room.');

    final body = disconnected
        ? 'Live voice mode starts after the room connects. Staff directory stays available on this screen.'
        : (agentReady
            ? 'LiveKit is connected and the employee directory stays available while you talk.'
            : 'Assistant audio will play through LiveKit as soon as the agent session becomes active.');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.darkSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.darkOutline),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x24000000),
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
                  center: const Alignment(0, -0.25),
                  radius: 0.95,
                  colors: <Color>[
                    palette.blue500.withValues(alpha: 0.14),
                    palette.darkSurface,
                    palette.darkBackground,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              children: <Widget>[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    _InfoPill(
                      icon: Icons.mic,
                      label: appState.isMicrophoneEnabled
                          ? 'MIC HOT'
                          : 'MIC OFF',
                      dark: true,
                    ),
                    _InfoPill(
                      icon: Icons.groups_2_outlined,
                      label: appState.hasEmployeeDirectory
                          ? '${appState.employeeDirectory.length} STAFF'
                          : 'STAFF NOT LOADED',
                      dark: true,
                    ),
                  ],
                ),
                const Spacer(),
                _AssistantVisualizer(
                  active: agentReady || appState.isConnected,
                  palette: palette,
                ),
                const SizedBox(height: 28),
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 38,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeDirectoryPanel extends StatefulWidget {
  const _EmployeeDirectoryPanel({
    required this.title,
    required this.subtitle,
    required this.appState,
    required this.dark,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final AppState appState;
  final bool dark;
  final Future<void> Function() onRefresh;

  @override
  State<_EmployeeDirectoryPanel> createState() =>
      _EmployeeDirectoryPanelState();
}

class _EmployeeDirectoryPanelState extends State<_EmployeeDirectoryPanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<MilaPalette>()!;
    final surface = widget.dark
        ? palette.darkSurface.withValues(alpha: 0.98)
        : Colors.white;
    final border = widget.dark ? palette.darkOutline : palette.lightOutline;
    final textColor = widget.dark ? Colors.white : const Color(0xFF111111);
    final subdued = widget.dark
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF5B5B58);
    final filteredEmployees = widget.appState.employeeDirectory
        .where((employee) => employee.matchesQuery(_query))
        .toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: textColor,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: subdued,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.appState.hasBackendBaseUrl
                      ? widget.onRefresh
                      : null,
                  style: IconButton.styleFrom(
                    backgroundColor: widget.dark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF3F3F0),
                    foregroundColor: textColor,
                  ),
                  icon: widget.appState.isEmployeeDirectoryLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.dark ? Colors.white : palette.blue500,
                            ),
                          ),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
              style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
              decoration: InputDecoration(
                hintText: 'Search by name, number, position, or Telegram',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(color: subdued),
                prefixIcon: Icon(Icons.search, color: subdued),
                filled: true,
                fillColor: widget.dark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF6F6F3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: widget.dark
                        ? Colors.white.withValues(alpha: 0.18)
                        : palette.blue500.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (!widget.appState.hasBackendBaseUrl)
              _PanelMessage(
                dark: widget.dark,
                title: 'Backend URL not saved',
                body:
                    'Open Settings, save your backend URL, and the employee directory will load automatically.',
              )
            else if (widget.appState.employeeDirectoryError != null)
              _PanelMessage(
                dark: widget.dark,
                title: 'Could not load employees',
                body: widget.appState.employeeDirectoryError!,
              )
            else if (widget.appState.isEmployeeDirectoryLoading &&
                widget.appState.employeeDirectory.isEmpty)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.dark ? Colors.white : palette.blue500,
                    ),
                  ),
                ),
              )
            else if (filteredEmployees.isEmpty)
              Expanded(
                child: _PanelMessage(
                  dark: widget.dark,
                  title: 'No matching employees',
                  body: _query.trim().isEmpty
                      ? 'No active employees were returned by the backend.'
                      : 'Try a different search term.',
                ),
              )
            else ...<Widget>[
              Text(
                '${filteredEmployees.length} employees',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: subdued,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: filteredEmployees.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final employee = filteredEmployees[index];
                    return _EmployeeCard(employee: employee, dark: widget.dark);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee, required this.dark});

  final EmployeeRecord employee;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = dark ? Colors.white : const Color(0xFF151515);
    final secondary = dark
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF5C5C59);
    final surface = dark
        ? Colors.white.withValues(alpha: 0.04)
        : const Color(0xFFF7F7F4);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    employee.badgeLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        employee.fullName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: textColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (employee.position != null ||
                          employee.departmentTitle != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (employee.position != null) employee.position!,
                            if (employee.departmentTitle != null)
                              employee.departmentTitle!,
                          ].join(' В· '),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (employee.telegramUsername != null ||
                employee.phone != null ||
                employee.accessLevel != null) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (employee.telegramUsername != null)
                    _MiniPill(
                      label: '@${employee.telegramUsername!}',
                      dark: dark,
                    ),
                  if (employee.phone != null)
                    _MiniPill(label: employee.phone!, dark: dark),
                  if (employee.accessLevel != null)
                    _MiniPill(label: employee.accessLevel!, dark: dark),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage({
    required this.dark,
    required this.title,
    required this.body,
  });

  final bool dark;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.info_outline,
              color: dark ? Colors.white70 : const Color(0xFF4A4A46),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: dark ? Colors.white : const Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: dark
                    ? Colors.white.withValues(alpha: 0.68)
                    : const Color(0xFF5B5B58),
              ),
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
    required this.onToggleEmployeePanel,
    required this.onToggleMicrophone,
    required this.showEmployeePanel,
    required this.palette,
  });

  final AppState appState;
  final Future<void> Function() onDisconnect;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onToggleCamera;
  final VoidCallback onToggleEmployeePanel;
  final Future<void> Function() onToggleMicrophone;
  final bool showEmployeePanel;
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
              icon: Icons.groups_2_outlined,
              active: showEmployeePanel,
              onPressed: onToggleEmployeePanel,
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
      width: 320,
      height: 320,
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

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.dark});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: dark ? Colors.white : const Color(0xFF1A1A1A),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECE9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD0C9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, color: Color(0xFF9C2F20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6A2117)),
            ),
          ),
        ],
      ),
    );
  }
}
