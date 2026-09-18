import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/match.dart';
import '../providers/copa_2026_provider.dart';
import '../providers/today_matches_provider.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../utils/team_names_pt.dart';
import '../widgets/match_card.dart';
import '../widgets/notification_toggle.dart';
import 'history_screen.dart';
import 'match_detail_screen.dart';
import 'stats_screen.dart';
import 'quiz_screen.dart';
import 'bolao_screen.dart';
import 'competitions_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _DashboardTab(),
    CompetitionsListScreen(),
    BolaoScreen(),
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
        backgroundColor: const Color(0xFF0A0A0A),
        indicatorColor: const Color(0xFFFFD700).withValues(alpha: 0.2),
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public),
            label: 'Campeonatos',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Bolão',
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

class _DashboardTabState extends State<_DashboardTab>
    with WidgetsBindingObserver {
  late ScrollController _scroll;
  bool _collapsed = false;

  // Campeonatos escondidos do "Jogos de Hoje"/"Próximos Jogos" — filtro
  // local da tela, não persiste entre sessões (não é uma preferência
  // duradoura, é só pra afinar o que se vê agora).
  final Set<String> _hiddenCompetitions = {};

  static const _collapseThreshold = 80.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll = ScrollController();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<Copa2026Provider>().load();
      context.read<TodayMatchesProvider>().load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Reagenda notificações sempre que o app volta ao primeiro plano
      context.read<Copa2026Provider>().load();
      context.read<TodayMatchesProvider>().load();
    }
  }

  void _onScroll() {
    final isCollapsed = _scroll.offset > _collapseThreshold;
    if (isCollapsed != _collapsed) {
      setState(() => _collapsed = isCollapsed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<Copa2026Provider>();
    final todayProvider = context.watch<TodayMatchesProvider>();
    final today = DateTime.now();
    final dateStr = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(today);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    LabeledMatch asCopaLabeled(Match m) => LabeledMatch(
        match: m, competitionName: 'Copa do Mundo 2026', competitionEmoji: '🏆');
    final rawToday = <LabeledMatch>[
      ...provider.todayMatches.map(asCopaLabeled),
      ...todayProvider.today(),
    ]..sort((a, b) => a.match.dateTime.compareTo(b.match.dateTime));
    final rawNextDays = <LabeledMatch>[
      ...provider.nextDaysMatches.map(asCopaLabeled),
      ...todayProvider.nextDays(),
    ]..sort((a, b) => a.match.dateTime.compareTo(b.match.dateTime));

    // Só os campeonatos que realmente têm jogo na janela atual viram chip —
    // não faz sentido oferecer filtro pra um campeonato sem nenhum jogo hoje
    // ou nos próximos dias. O contador do chip soma hoje + próximos dias,
    // pra nunca mostrar "0" num campeonato que só tem jogo em outra parte
    // da janela.
    final matchCounts = <String, int>{};
    for (final lm in [...rawToday, ...rawNextDays]) {
      matchCounts[lm.competitionName] = (matchCounts[lm.competitionName] ?? 0) + 1;
    }
    final availableCompetitions = matchCounts.keys.toList()..sort();
    // Interseção em vez de mutar `_hiddenCompetitions` aqui — mantém o
    // "build" livre de efeito colateral; um campeonato escondido que some da
    // janela atual (ex.: não tem mais jogo nos próximos dias) simplesmente
    // não aparece nem como chip nem no filtro, sem precisar limpar o state.
    final effectiveHidden =
        _hiddenCompetitions.intersection(availableCompetitions.toSet());

    final labeledToday = rawToday
        .where((lm) => !effectiveHidden.contains(lm.competitionName))
        .toList();
    final labeledNextDays = rawNextDays
        .where((lm) => !effectiveHidden.contains(lm.competitionName))
        .toList();
    final loadingToday = provider.loading || todayProvider.loading;
    final liveNow = labeledToday.where((lm) => lm.match.isLive).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          context.read<Copa2026Provider>().refresh(),
          context.read<TodayMatchesProvider>().load(force: true),
        ]),
        color: AppColors.gold,
        backgroundColor: AppColors.green,
        child: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            expandedHeight: isTablet ? 200 : 170,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF121212),
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
          if (liveNow.isNotEmpty)
            SliverToBoxAdapter(child: _LiveNowBanner(liveMatches: liveNow)),
          SliverToBoxAdapter(
            child: _SectionTitle(
              icon: Icons.today,
              title: 'Jogos de Hoje',
              subtitle: 'Todos os campeonatos',
            ),
          ),
          if (availableCompetitions.length > 1)
            SliverToBoxAdapter(
              child: _CompetitionFilterRow(
                competitions: availableCompetitions,
                hidden: effectiveHidden,
                counts: matchCounts,
                onToggle: (name) => setState(() {
                  if (!_hiddenCompetitions.add(name)) {
                    _hiddenCompetitions.remove(name);
                  }
                }),
              ),
            ),
          if (loadingToday)
            const SliverToBoxAdapter(child: _SkeletonMatchList(count: 3))
          else if (provider.error != null)
            SliverToBoxAdapter(
                child: _ErrorCard(message: provider.error!))
          else if (labeledToday.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyMatchesCard(upcomingMatches: labeledNextDays),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => MatchCard(
                  match: labeledToday[i].match,
                  competitionLabel:
                      '${labeledToday[i].competitionEmoji} ${labeledToday[i].competitionName}',
                  competitionId: labeledToday[i].competitionId,
                  show2026Actions:
                      labeledToday[i].competitionName == 'Copa do Mundo 2026',
                  heroTag: 'home-today-${labeledToday[i].match.matchKey}',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchDetailScreen(
                        match: labeledToday[i].match,
                        competitionId: labeledToday[i].competitionId,
                        show2026Actions: labeledToday[i].competitionName ==
                            'Copa do Mundo 2026',
                        heroTag: 'home-today-${labeledToday[i].match.matchKey}',
                      ),
                    ),
                  ),
                ),
                childCount: labeledToday.length,
              ),
            ),
          if (!loadingToday &&
              labeledToday.isEmpty &&
              labeledNextDays.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionTitle(
                icon: Icons.schedule,
                title: 'Próximos Jogos',
                subtitle: 'Próximos 4 dias · todos os campeonatos',
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => MatchCard(
                  match: labeledNextDays[i].match,
                  competitionLabel:
                      '${labeledNextDays[i].competitionEmoji} ${labeledNextDays[i].competitionName}',
                  competitionId: labeledNextDays[i].competitionId,
                  show2026Actions: labeledNextDays[i].competitionName ==
                      'Copa do Mundo 2026',
                  heroTag: 'home-next-${labeledNextDays[i].match.matchKey}',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchDetailScreen(
                        match: labeledNextDays[i].match,
                        competitionId: labeledNextDays[i].competitionId,
                        show2026Actions: labeledNextDays[i].competitionName ==
                            'Copa do Mundo 2026',
                        heroTag: 'home-next-${labeledNextDays[i].match.matchKey}',
                      ),
                    ),
                  ),
                ),
                childCount: labeledNextDays.length,
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
                  icon: Icons.public,
                  title: 'Campeonatos',
                  subtitle: 'Copa, Euro, Champions, ligas...',
                  onTap: () => _goToTab(context, 1),
                ),
                _NavCard(
                  icon: Icons.emoji_events,
                  title: 'Bolão',
                  subtitle: 'Faça seus palpites',
                  onTap: () => _goToTab(context, 2),
                ),
                _NavCard(
                  icon: Icons.history,
                  title: 'História',
                  subtitle: '1930 – 2022',
                  onTap: () => _goToTab(context, 3),
                ),
                _NavCard(
                  icon: Icons.bar_chart,
                  title: 'Estatísticas',
                  subtitle: 'Gráficos e rankings',
                  onTap: () => _goToTab(context, 4),
                ),
                _NavCard(
                  icon: Icons.quiz,
                  title: 'Quiz',
                  subtitle: 'Teste seu conhecimento',
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
              colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
            ),
          ),
        ),
        // Logo grande centralizada (desaparece ao colapsar)
        Positioned.fill(
          child: Align(
            alignment: const Alignment(0, -0.2),
            child: Image.asset(
              'logoCampeonatos_full.png',
              height: isTablet ? 130 : 105,
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
          'logoCampeonatos_icon.png',
          height: 30,
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

// ── Filtro de campeonatos (Jogos de Hoje / Próximos Jogos) ──────────────────────

class _CompetitionFilterRow extends StatelessWidget {
  final List<String> competitions;
  final Set<String> hidden;
  final Map<String, int> counts;
  final ValueChanged<String> onToggle;

  const _CompetitionFilterRow({
    required this.competitions,
    required this.hidden,
    required this.counts,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: competitions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final name = competitions[i];
          final selected = !hidden.contains(name);
          final count = counts[name] ?? 0;
          return GestureDetector(
            onTap: () => onToggle(name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(colors: [
                        AppColors.gold.withValues(alpha: 0.24),
                        AppColors.gold.withValues(alpha: 0.06),
                      ])
                    : null,
                color: selected ? null : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppColors.gold.withValues(alpha: 0.6)
                      : Colors.white12,
                  width: selected ? 1.4 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: selected ? AppColors.gold : Colors.white38,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.gold : Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: selected ? Colors.black : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Banner "Ao Vivo Agora" ───────────────────────────────────────────────────────

class _LiveNowBanner extends StatefulWidget {
  final List<LabeledMatch> liveMatches;
  const _LiveNowBanner({required this.liveMatches});

  @override
  State<_LiveNowBanner> createState() => _LiveNowBannerState();
}

class _LiveNowBannerState extends State<_LiveNowBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lm = widget.liveMatches.first;
    final extra = widget.liveMatches.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchDetailScreen(
              match: lm.match,
              competitionId: lm.competitionId,
              show2026Actions: lm.competitionName == 'Copa do Mundo 2026',
            ),
          ),
        ),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final glow = 0.12 + 0.18 * _pulse.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3A0A0A), Color(0xFF1A1A1A)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.live.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.live.withValues(alpha: glow),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Row(
            children: [
              FadeTransition(
                opacity: Tween(begin: 1.0, end: 0.3).animate(_pulse),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: AppColors.live, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AO VIVO AGORA',
                        style: TextStyle(
                            color: AppColors.live,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 3),
                    Text(
                      '${TeamNamesPt.translate(lm.match.team1)} x ${TeamNamesPt.translate(lm.match.team2)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(lm.competitionName,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              if (extra > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('+$extra',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeleton de loading ───────────────────────────────────────────────────────

class _SkeletonMatchList extends StatelessWidget {
  final int count;
  const _SkeletonMatchList({required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (_) => const _ShimmerBox(
          height: 118,
          margin: EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double height;
  final EdgeInsets margin;
  const _ShimmerBox({required this.height, required this.margin});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment(-1 + 3 * t, 0),
              end: Alignment(3 * t, 0),
              colors: const [
                Color(0xFF1A1A1A),
                Color(0xFF2A2A2A),
                Color(0xFF1A1A1A),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Nav Card ──────────────────────────────────────────────────────────────────

class _NavCard extends StatelessWidget {
  /// Visual único pra todos os cards do grid Explorar — reforça "um só
  /// intuito" no app inteiro em vez de cada seção ter sua própria cor.
  static const _sharedGradient = LinearGradient(
    colors: [Color(0xFF1E1E1E), Color(0xFF181818)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: _sharedGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
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
  final List<LabeledMatch> upcomingMatches;
  const _EmptyMatchesCard({required this.upcomingMatches});

  @override
  Widget build(BuildContext context) {
    final nextDate = upcomingMatches.isNotEmpty
        ? upcomingMatches.first.match.date
        : kWorldCupStartLabel;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
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
