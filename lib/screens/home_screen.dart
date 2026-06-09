import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/copa_2026_provider.dart';
import '../widgets/match_card.dart';
import '../widgets/notification_toggle.dart';
import 'copa_2026_screen.dart';
import 'history_screen.dart';
import 'stats_screen.dart';
import 'quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _DashboardTab(),
    Copa2026Screen(),
    HistoryScreen(),
    StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xFF0A150A),
        indicatorColor: const Color(0xFFFFD700).withValues(alpha: 0.2),
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_soccer_outlined),
            selectedIcon: Icon(Icons.sports_soccer),
            label: 'Copa 2026',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'História',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  late ScrollController _scroll;
  bool _collapsed = false;

  // A logo fica "colapsada" quando o scroll passa de ~80px
  static const _collapseThreshold = 80.0;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<Copa2026Provider>().load();
    });
  }

  void _onScroll() {
    final isCollapsed = _scroll.offset > _collapseThreshold;
    if (isCollapsed != _collapsed) {
      setState(() => _collapsed = isCollapsed);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<Copa2026Provider>();
    final today = DateTime.now();
    final dateStr = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(today);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            expandedHeight: isTablet ? 200 : 170,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0D1A0D),
            actions: [
              NotificationToggle(matches: provider.matches),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 12),
              // Título: logo pequena aparece APENAS quando colapsado
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _collapsed
                    ? _CollapsedTitle(key: const ValueKey('collapsed'))
                    : const _ExpandedTitle(key: ValueKey('expanded')),
              ),
              background: _HeaderBackground(isTablet: isTablet),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                dateStr,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _SectionTitle(
              icon: Icons.today,
              title: 'Jogos de Hoje',
              subtitle: 'Copa do Mundo 2026',
            ),
          ),
          if (provider.loading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child:
                      CircularProgressIndicator(color: Color(0xFFFFD700)),
                ),
              ),
            )
          else if (provider.error != null)
            SliverToBoxAdapter(
                child: _ErrorCard(message: provider.error!))
          else if (provider.todayMatches.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyMatchesCard(
                  upcomingMatches: provider.nextDaysMatches),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => MatchCard(
                  match: provider.todayMatches[i],
                  show2026Actions: true,
                ),
                childCount: provider.todayMatches.length,
              ),
            ),
          if (!provider.loading &&
              provider.todayMatches.isEmpty &&
              provider.nextDaysMatches.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionTitle(
                icon: Icons.schedule,
                title: 'Próximos Jogos',
                subtitle: 'Próximos 4 dias',
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => MatchCard(
                  match: provider.nextDaysMatches[i],
                  show2026Actions: true,
                ),
                childCount: provider.nextDaysMatches.length,
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: _SectionTitle(
              icon: Icons.grid_view,
              title: 'Explorar',
              subtitle: '',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTablet ? 4 : 2,
                childAspectRatio: isTablet ? 1.4 : 1.55,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              delegate: SliverChildListDelegate([
                _NavCard(
                  icon: Icons.sports_soccer,
                  title: 'Copa 2026',
                  subtitle: '80 jogos • 48 seleções',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A6B35), Color(0xFF0D3D1E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => _goToTab(context, 1),
                ),
                _NavCard(
                  icon: Icons.history,
                  title: 'História',
                  subtitle: '1930 – 2022',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A3A5C), Color(0xFF0D1A2E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => _goToTab(context, 2),
                ),
                _NavCard(
                  icon: Icons.bar_chart,
                  title: 'Estatísticas',
                  subtitle: 'Gráficos e rankings',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A1A6B), Color(0xFF220D3D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => _goToTab(context, 3),
                ),
                _NavCard(
                  icon: Icons.quiz,
                  title: 'Quiz',
                  subtitle: 'Teste seu conhecimento',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B3A1A), Color(0xFF3D1E0D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const QuizScreen()),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _goToTab(BuildContext context, int index) {
    final homeState =
        context.findAncestorStateOfType<_HomeScreenState>();
    homeState?.setState(() => homeState._currentIndex = index);
  }
}

// ── Header components ─────────────────────────────────────────────────────────

// Fundo do header expansível: mostra a logo grande centralizada
class _HeaderBackground extends StatelessWidget {
  final bool isTablet;
  const _HeaderBackground({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A472A), Color(0xFF0D1A0D)],
            ),
          ),
        ),
        // Logo grande centralizada (desaparece ao colapsar)
        Positioned.fill(
          child: Align(
            alignment: const Alignment(0, -0.2),
            child: Image.asset(
              'logo2.png',
              height: isTablet ? 110 : 90,
              errorBuilder: (_, _, _) =>
                  const Text('🏆', style: TextStyle(fontSize: 52)),
            ),
          ),
        ),
      ],
    );
  }
}

// Título quando expandido: apenas texto simples (logo está no background)
class _ExpandedTitle extends StatelessWidget {
  const _ExpandedTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Calm Cup',
      style: TextStyle(
        color: Color(0xFFFFD700),
        fontWeight: FontWeight.bold,
        fontSize: 18,
        letterSpacing: 0.5,
      ),
    );
  }
}

// Título quando colapsado: logo pequena + texto
class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'logo2.png',
          height: 26,
          errorBuilder: (_, _, _) =>
              const Text('🏆', style: TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 8),
        const Text(
          'Calm Cup',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(subtitle,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

// ── Nav Card ──────────────────────────────────────────────────────────────────

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFFFD700), size: 24),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ── Empty / Error cards ───────────────────────────────────────────────────────

class _EmptyMatchesCard extends StatelessWidget {
  final List upcomingMatches;
  const _EmptyMatchesCard({required this.upcomingMatches});

  @override
  Widget build(BuildContext context) {
    final nextDate = upcomingMatches.isNotEmpty
        ? upcomingMatches.first.date
        : '11/06/2026';
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          const Text('⚽', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          const Text('Nenhum jogo hoje',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Próximo jogo: $nextDate',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text('Erro ao carregar dados.\nVerifique sua conexão.',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
