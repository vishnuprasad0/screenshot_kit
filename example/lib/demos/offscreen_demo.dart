import 'package:flutter/material.dart';
import 'package:screenshot_kit/screenshot_kit.dart';

import '../app_settings.dart';
import '../preview_page.dart';

/// Demo 2: capture widgets that are never shown on screen.
///
/// `captureWidget(widget, context: context)` renders the widget off-screen
/// inside the app, so it can read the [AppSettingsScope] declared above
/// `MaterialApp`, plus the theme and media query.
///
/// Providers declared *inside* a page are not visible to the app-level
/// overlay. Wrapping the page in a [ScreenshotHost] makes the capture happen
/// below them, as the second button shows.
class OffscreenDemo extends StatefulWidget {
  const OffscreenDemo({super.key});

  @override
  State<OffscreenDemo> createState() => _OffscreenDemoState();
}

class _OffscreenDemoState extends State<OffscreenDemo> {
  final _controller = ScreenshotController();
  final _name = TextEditingController(text: 'Ada Lovelace');

  static const _accents = <String, Color>{
    'Purple': Colors.deepPurple,
    'Teal': Colors.teal,
    'Orange': Colors.deepOrange,
    'Blue': Colors.blue,
  };

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Off-screen widget')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'The cards below are never shown. They read the app-level '
            'AppSettings (name and accent colour) when they are captured.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'User name',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => settings.userName = v,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in _accents.entries)
                ChoiceChip(
                  label: Text(entry.key),
                  avatar: CircleAvatar(backgroundColor: entry.value),
                  selected: settings.accent == entry.value,
                  onSelected: (_) => settings.accent = entry.value,
                ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: CaptureButton(
              label: 'Capture share card',
              capture: () => _controller.captureWidget(
                const ShareCard(),
                // The context lets the card find AppSettingsScope.
                context: context,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 32),
          // A provider that only exists inside this page.
          CampaignScope(
            campaign: 'Spring sale',
            child: ScreenshotHost(
              child: Builder(
                // This context is below the host, so the captured widget
                // is rendered where CampaignScope is visible.
                builder: (context) => Align(
                  alignment: Alignment.centerLeft,
                  child: CaptureButton(
                    label: 'Capture with ScreenshotHost',
                    filled: false,
                    icon: Icons.layers_outlined,
                    capture: () => _controller.captureWidget(
                      const CampaignBanner(),
                      context: context,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card that reads [AppSettings] from the app-level provider.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final accent = settings.accent;
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 360,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, Color.lerp(accent, Colors.black, 0.45)!],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite, color: Colors.white, size: 44),
              const SizedBox(height: 16),
              Text(
                settings.userName.isEmpty ? 'Anonymous' : settings.userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'shared a screenshot_kit card',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white.withValues(
                        alpha: 0.25 + i * 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A provider that is only declared inside the off-screen demo page.
class CampaignScope extends InheritedWidget {
  const CampaignScope({
    super.key,
    required this.campaign,
    required super.child,
  });

  final String campaign;

  static CampaignScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CampaignScope>();
    assert(scope != null, 'No CampaignScope above this context');
    return scope!;
  }

  @override
  bool updateShouldNotify(CampaignScope oldWidget) =>
      campaign != oldWidget.campaign;
}

/// Reads both the page-scoped [CampaignScope] and the app-level settings.
class CampaignBanner extends StatelessWidget {
  const CampaignBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final campaign = CampaignScope.of(context).campaign;
    final settings = AppSettingsScope.of(context);
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 360,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: settings.accent.withValues(alpha: 0.15),
            border: Border.all(color: settings.accent, width: 3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.local_offer, color: settings.accent, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign,
                      style: TextStyle(
                        color: settings.accent,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Hello, ${settings.userName}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
