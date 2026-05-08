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
    final palette = Theme.of(context).extension<MilaPalette>()!;
    final inCall = !kIsWeb && (appState.isConnected || appState.isConnecting);

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
    final agentReady = appState.remoteParticipantNames.isNotEmpty;

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
                  agentReady
                      ? 'Mila is ready to listen.'
                      : 'Waiting for Mila to join the room.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 38,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  agentReady
                      ? 'LiveKit is connected and the employee directory stays available while you talk.'
                      : 'Assistant audio will play through LiveKit as soon as the agent session becomes active.',
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
                          ].join(' · '),
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
