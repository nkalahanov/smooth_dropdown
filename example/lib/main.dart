import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

void main() => runApp(const SmoothGalleryApp());

/// The demo app for the smooth_dropdown package.
class SmoothGalleryApp extends StatelessWidget {
  /// Makes the demo app.
  const SmoothGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smooth Dropdown',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(scaffoldBackgroundColor: const Color(0xFF05050A)),
      home: const _GalleryPage(),
    );
  }
}

/// A custom color set that ships with no preset, to show full color control.
const SmoothPalette _sunset = SmoothPalette(
  accent: Color(0xFFFDBA74),
  accentBright: Color(0xFFFFEDD5),
  accentDeep: Color(0xFFF97316),
  fillTop: Color(0xFF2A1A10),
  fillBottom: Color(0xFF130A05),
);

class _GalleryPage extends StatefulWidget {
  const _GalleryPage();

  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<_GalleryPage>
    with SingleTickerProviderStateMixin {
  static const int _sectionCount = 8;

  late final AnimationController _entrance;
  late final List<Animation<double>> _reveals;
  final SmoothExpansionController _tasksTile = SmoothExpansionController();

  String? _fruit;
  String _plan = 'free';
  String _voice = 'aria';
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
    _reveals = List<Animation<double>>.generate(_sectionCount, (index) {
      final start = (0.07 * index).clamp(0.0, 0.55);
      return CurvedAnimation(
        parent: _entrance,
        curve: Interval(
          start,
          (start + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      );
    });
    unawaited(_entrance.forward());
  }

  @override
  void dispose() {
    for (final reveal in _reveals) {
      if (reveal is CurvedAnimation) reveal.dispose();
    }
    _entrance.dispose();
    _tasksTile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget gallery = ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 56),
      children: <Widget>[
        _hero(),
        _sectionHeader(
          'Pick one — themed selects',
          'Three palettes. Colors, icons, and the sheen are all replaceable.',
          _reveals[0],
        ),
        _fruitSelect(),
        const SizedBox(height: 14),
        _planSelect(),
        const SizedBox(height: 14),
        _voiceSelect(),
        _sectionHeader(
          'One custom style',
          'A hand-built palette, bigger radius, taller wave, springy arrow.',
          _reveals[3],
        ),
        _customStyleTile(),
        _sectionHeader(
          'FAQ — text that rises as it opens',
          'The short SmoothExpansionTile.text factory.',
          _reveals[4],
        ),
        _faqTile(
          'What is it?',
          'A set of widgets. The open and close move is a wavy '
              'clip, a soft glow, a light sheen, and a small squash. It all '
              'runs on the render layer.',
          Icons.water_drop_rounded,
          _reveals[4],
          'faq-what',
        ),
        const SizedBox(height: 12),
        _faqTile(
          'Can it hold any widget?',
          'Yes. A tile can show any content. This text tile is just one easy '
              'way to use it.',
          Icons.auto_awesome_rounded,
          _reveals[5],
          'faq-any',
        ),
        _sectionHeader(
          'Any content + your own control',
          'Chips, a banner, and buttons. Open and close it from outside too.',
          _reveals[6],
        ),
        _controlRow(),
        const SizedBox(height: 10),
        _anyContentTile(),
        _sectionHeader(
          'Your own header and arrow',
          'A full custom header with a plus that morphs on open.',
          _reveals[7],
        ),
        _customHeaderTile(),
      ],
    );

    if (_reduceMotion) {
      gallery = MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: gallery,
      );
    }

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _GlowBackdrop()),
          SafeArea(child: gallery),
        ],
      ),
    );
  }

  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Smooth Dropdown',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Selects and tiles that open with a smooth move.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _reduceMotionToggle(),
        ],
      ),
    );
  }

  Widget _reduceMotionToggle() {
    return Column(
      children: <Widget>[
        Icon(
          _reduceMotion
              ? Icons.motion_photos_off_rounded
              : Icons.motion_photos_on_rounded,
          size: 20,
          color: Colors.white.withValues(alpha: 0.6),
        ),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: _reduceMotion,
            activeThumbColor: const Color(0xFF7DD3FC),
            onChanged: (value) => setState(() => _reduceMotion = value),
          ),
        ),
      ],
    );
  }

  Widget _fruitSelect() {
    return SmoothSelect<String>(
      value: _fruit,
      entrance: _reveals[0],
      hint: const Text('Pick a fruit'),
      leading: const Icon(Icons.eco_rounded),
      onChanged: (value) => setState(() => _fruit = value),
      items: const <SmoothSelectItem<String>>[
        SmoothSelectItem<String>(
          value: 'apple',
          leading: Icon(Icons.circle, size: 12, color: Color(0xFFEF4444)),
          child: Text('Apple'),
        ),
        SmoothSelectItem<String>(
          value: 'lime',
          leading: Icon(Icons.circle, size: 12, color: Color(0xFF84CC16)),
          child: Text('Lime'),
        ),
        SmoothSelectItem<String>(
          value: 'plum',
          leading: Icon(Icons.circle, size: 12, color: Color(0xFF8B5CF6)),
          child: Text('Plum'),
        ),
        SmoothSelectItem<String>(
          value: 'gone',
          enabled: false,
          leading: Icon(Icons.circle, size: 12, color: Color(0xFF52525B)),
          child: Text('Sold out'),
        ),
      ],
    );
  }

  Widget _planSelect() {
    return SmoothTheme(
      data: const SmoothStyle(palette: SmoothPalette.orchid),
      child: SmoothSelect<String>(
        value: _plan,
        entrance: _reveals[1],
        leading: const Icon(Icons.workspace_premium_rounded),
        onChanged: (value) => setState(() => _plan = value ?? 'free'),
        items: const <SmoothSelectItem<String>>[
          SmoothSelectItem<String>(value: 'free', child: Text('Free')),
          SmoothSelectItem<String>(value: 'pro', child: Text('Pro')),
          SmoothSelectItem<String>(value: 'team', child: Text('Team')),
        ],
      ),
    );
  }

  Widget _voiceSelect() {
    return SmoothTheme(
      data: const SmoothStyle(palette: SmoothPalette.mint),
      child: SmoothSelect<String>(
        value: _voice,
        entrance: _reveals[2],
        leading: const Icon(Icons.graphic_eq_rounded),
        onChanged: (value) => setState(() => _voice = value ?? 'aria'),
        selectedItemBuilder: (context, item) => Row(
          children: <Widget>[
            const Text('Voice: ', style: TextStyle(color: Color(0xFF6EE7B7))),
            DefaultTextStyle.merge(
              style: const TextStyle(fontWeight: FontWeight.w700),
              child: item.child,
            ),
          ],
        ),
        items: const <SmoothSelectItem<String>>[
          SmoothSelectItem<String>(value: 'aria', child: Text('Aria')),
          SmoothSelectItem<String>(value: 'cove', child: Text('Cove')),
          SmoothSelectItem<String>(value: 'sol', child: Text('Sol')),
        ],
      ),
    );
  }

  Widget _customStyleTile() {
    const style = SmoothStyle(
      palette: _sunset,
      radius: 26,
      waveAmplitude: 16,
      waveSegments: 72,
      motion: SmoothMotionSpec(
        expandDuration: Duration(milliseconds: 720),
        collapseDuration: Duration(milliseconds: 620),
        expandCurve: Curves.easeOutQuint,
        chevronCurve: Curves.elasticOut,
      ),
    );
    return SmoothExpansionTile(
      style: style,
      entrance: _reveals[3],
      leading: const Icon(Icons.local_fire_department_rounded),
      title: const Text('Sunset preset'),
      subtitle: const Text('Every knob is set by hand'),
      child: Text(
        'This card uses a custom palette with no preset, a wider corner '
        'radius, a taller bottom wave, and a springy arrow curve. None of it '
        'is hardcoded in the widget — it all comes from SmoothStyle.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _faqTile(
    String title,
    String text,
    IconData icon,
    Animation<double> entrance,
    Object seed,
  ) {
    return SmoothExpansionTile.text(
      title: title,
      text: text,
      icon: icon,
      entrance: entrance,
      phaseSeed: seed,
    );
  }

  Widget _controlRow() {
    return _Reveal(
      animation: _reveals[6],
      child: ListenableBuilder(
        listenable: _tasksTile,
        builder: (context, _) {
          final open = _tasksTile.isExpanded;
          final icon = open
              ? Icons.unfold_less_rounded
              : Icons.unfold_more_rounded;
          return Row(
            children: <Widget>[
              _ghostButton(
                icon: icon,
                label: open ? 'Collapse' : 'Expand',
                onTap: _tasksTile.toggle,
              ),
              const SizedBox(width: 10),
              Text(
                open ? 'Open' : 'Closed',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _anyContentTile() {
    return SmoothExpansionTile(
      controller: _tasksTile,
      entrance: _reveals[6],
      leading: const Icon(Icons.dashboard_customize_rounded),
      title: const Text('Custom content'),
      subtitle: const Text('Banner, chips, and a button'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 68,
            width: double.infinity,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF38BDF8), Color(0xFF818CF8)],
              ),
            ),
            child: const Text(
              'Any widget fits inside',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final label in const <String>['Design', 'Build', 'Ship'])
                Chip(label: Text(label)),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _tasksTile.collapse,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Close from inside'),
          ),
        ],
      ),
    );
  }

  Widget _customHeaderTile() {
    return SmoothExpansionTile(
      entrance: _reveals[7],
      style: const SmoothStyle(palette: SmoothPalette.mint),
      headerBuilder: (context, expand, controller) => GestureDetector(
        onTap: controller.toggle,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              const _Avatar(),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Ava Reeves',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Product designer',
                      style: TextStyle(
                        color: Color(0x996EE7B7),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              _MorphPlus(expand: expand),
            ],
          ),
        ),
      ),
      child: Text(
        'The whole header is yours. This one has an avatar, two lines of '
        'text, and a plus mark that turns into a cross as the tile opens. '
        'It is all driven by the open value the builder gives you.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _ghostButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          color: Colors.white.withValues(alpha: 0.04),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
    String title,
    String caption,
    Animation<double> animation,
  ) {
    return _Reveal(
      animation: animation,
      child: Padding(
        padding: const EdgeInsets.only(top: 30, bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades and slides a widget up, driven by one shared entrance value.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

/// A plus mark that turns forty-five degrees into a cross as the tile opens.
class _MorphPlus extends StatelessWidget {
  const _MorphPlus({required this.expand});

  final Animation<double> expand;

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: Tween<double>(begin: 0, end: 0.125).animate(expand),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x226EE7B7),
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 18,
          color: Color(0xFF6EE7B7),
        ),
      ),
    );
  }
}

/// A round gradient avatar with initials.
class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF6EE7B7), Color(0xFF10B981)],
        ),
      ),
      child: const Text(
        'AR',
        style: TextStyle(
          color: Color(0xFF07130D),
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// The soft ambient background behind the gallery.
class _GlowBackdrop extends StatelessWidget {
  const _GlowBackdrop();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0C0C18), Color(0xFF05050A)],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -130,
              left: -90,
              child: _Blob(color: Color(0x338B5CF6), size: 340),
            ),
            Positioned(
              bottom: -160,
              right: -110,
              child: _Blob(color: Color(0x2238BDF8), size: 380),
            ),
          ],
        ),
      ),
    );
  }
}

/// One soft, fading color circle.
class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
