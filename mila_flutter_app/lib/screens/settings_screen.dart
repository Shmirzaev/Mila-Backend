import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<AppState>().backendBaseUrl,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<MilaPalette>()!;
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: palette.lightBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: <Widget>[
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(_isSaving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: palette.lightOutline),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Row(
                            children: <Widget>[
                              _SettingsMark(),
                              SizedBox(width: 14),
                              Expanded(child: _SettingsTitleBlock()),
                            ],
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _controller,
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _save(),
                            decoration: const InputDecoration(
                              labelText: 'Backend URL',
                              hintText: 'https://my-domain.com',
                              helperText:
                                  'Save the base URL only. Do not add /token.',
                            ),
                          ),
                          if (_errorText != null) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              _errorText!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              _QuickInsertPill(
                                label: 'Web local',
                                value: 'http://127.0.0.1:8000',
                                onTap: _fill,
                              ),
                              _QuickInsertPill(
                                label: 'Android emulator',
                                value: 'http://10.0.2.2:8000',
                                onTap: _fill,
                              ),
                              _QuickInsertPill(
                                label: 'Phone on Wi-Fi',
                                value: 'http://10.100.50.39:8000',
                                onTap: _fill,
                              ),
                              _QuickInsertPill(
                                label: 'Production',
                                value: 'https://my-domain.com',
                                onTap: _fill,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _isSaving ? null : _save,
                            child: const Text('SAVE BACKEND URL'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: <Widget>[
                      _SettingsCard(
                        width: 420,
                        title: 'Platform routing',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const <Widget>[
                            _SettingsLine(
                              title: 'Web on same computer',
                              value: 'http://127.0.0.1:8000',
                            ),
                            _SettingsLine(
                              title: 'Android emulator',
                              value: 'http://10.0.2.2:8000',
                            ),
                            _SettingsLine(
                              title: 'Real iPhone or Android phone',
                              value: 'http://10.100.50.39:8000',
                            ),
                            _SettingsLine(
                              title: 'Production',
                              value: 'https://my-domain.com',
                            ),
                          ],
                        ),
                      ),
                      _SettingsCard(
                        width: 420,
                        title: 'Current session identity',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _SettingsLine(
                              title: 'Source',
                              value: appState.participantSource,
                            ),
                            _SettingsLine(
                              title: 'Identity',
                              value: appState.participantIdentity,
                            ),
                            _SettingsLine(
                              title: 'Display name',
                              value: appState.participantName,
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
      ),
    );
  }

  void _fill(String value) {
    _controller.text = value;
    setState(() {
      _errorText = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _errorText = null;
      _isSaving = true;
    });

    try {
      await context.read<AppState>().saveBackendBaseUrl(_controller.text);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } on FormatException catch (error) {
      setState(() {
        _errorText = error.message.toString();
      });
    } catch (_) {
      setState(() {
        _errorText = 'Could not save the backend URL. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _SettingsMark extends StatelessWidget {
  const _SettingsMark();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.asset(
        'assets/ui/mila_mark.png',
        width: 72,
        height: 72,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _SettingsTitleBlock extends StatelessWidget {
  const _SettingsTitleBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Backend base URL',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 6),
        Text(
          'This app asks your Python backend for a LiveKit token, then connects without storing any backend secrets on the device.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _QuickInsertPill extends StatelessWidget {
  const _QuickInsertPill({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: () => onTap(value),
      avatar: const Icon(Icons.arrow_upward, size: 16),
      label: Text(label),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.width,
    required this.title,
    required this.child,
  });

  final double width;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<MilaPalette>()!;

    return SizedBox(
      width: width,
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

class _SettingsLine extends StatelessWidget {
  const _SettingsLine({required this.title, required this.value});

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
