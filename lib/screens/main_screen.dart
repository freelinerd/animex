import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'my_list_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _previousIndex = 0;

  final List<Widget> _pages = [
    HomeScreen(),
    SearchScreen(),
    const MyListScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Barra de navegación del sistema completamente transparente
    // para que el navbar flotante se vea sobre el fondo negro
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    );
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge, // Contenido detrás de la barra del sistema
    );
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true, // El body se extiende detrás del navbar flotante
      body: _AnimatedPageStack(
        currentIndex: _currentIndex,
        previousIndex: _previousIndex,
        pages: _pages,
      ),
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
      ),
    );
  }
}

// ── Stack con animación de deslizamiento entre pestañas ───────────────────────
class _AnimatedPageStack extends StatefulWidget {
  final int currentIndex;
  final int previousIndex;
  final List<Widget> pages;

  const _AnimatedPageStack({
    required this.currentIndex,
    required this.previousIndex,
    required this.pages,
  });

  @override
  State<_AnimatedPageStack> createState() => _AnimatedPageStackState();
}

class _AnimatedPageStackState extends State<_AnimatedPageStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideIn;
  late Animation<Offset> _slideOut;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _setupAnimations(widget.previousIndex, widget.currentIndex);
    _controller.value = 1.0; // Empieza ya visible
  }

  @override
  void didUpdateWidget(_AnimatedPageStack old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _setupAnimations(widget.previousIndex, widget.currentIndex);
      _controller.forward(from: 0);
    }
  }

  void _setupAnimations(int from, int to) {
    // Desliza hacia la izquierda si avanzamos, hacia la derecha si retrocedemos
    final direction = to > from ? 1.0 : -1.0;

    _slideIn = Tween<Offset>(
      begin: Offset(0.06 * direction, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(-0.06 * direction, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Página saliente (solo visible durante la animación)
        if (widget.previousIndex != widget.currentIndex)
          AnimatedBuilder(
            animation: _controller,
            builder: (_, child) => SlideTransition(
              position: _slideOut,
              child: child,
            ),
            child: widget.pages[widget.previousIndex],
          ),

        // Página entrante
        AnimatedBuilder(
          animation: _controller,
          builder: (_, child) => FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideIn,
              child: child,
            ),
          ),
          child: widget.pages[widget.currentIndex],
        ),
      ],
    );
  }
}

// ── Navbar flotante ───────────────────────────────────────────────────────────
class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: bottomPadding + 16,
      ),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          // Fondo oscuro semi-transparente con blur visual
          color: const Color.fromARGB(255, 10, 10, 10),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Inicio',
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.search_rounded,
              label: 'Buscar',
              selected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: Icons.bookmarks_rounded,
              label: 'Mi Lista',
              selected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item del navbar ───────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? Colors.orange.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  key: ValueKey(selected),
                  size: selected ? 24 : 22,
                  color: selected ? Colors.orange : Colors.white38,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: selected ? Colors.orange : Colors.white38,
                  fontSize: 9,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 0.3,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}