import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/copa_2026_provider.dart';
import '../models/match.dart';
import '../models/stadium.dart';
import '../utils/team_flags.dart';
import '../utils/team_names_pt.dart';
import '../widgets/match_card.dart';
import 'match_detail_screen.dart';
import 'simulator_screen.dart';
import 'team_profile_screen.dart';

class Copa2026Screen extends StatefulWidget {
  const Copa2026Screen({super.key});

  @override
  State<Copa2026Screen> createState() => _Copa2026ScreenState();
}

class _Copa2026ScreenState extends State<Copa2026Screen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<Copa2026Provider>().load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A472A),
        title: Row(
          children: [
            Image.asset(
              'logo2.png',
              height: 28,
              errorBuilder: (_, _, _) =>
                  const Text('🏆', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Copa do Mundo 2026',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sports_esports, color: Color(0xFFFFD700)),
            tooltip: 'Simulador',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SimulatorScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD700),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 12),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Hoje'),
            Tab(text: 'Agenda'),
            Tab(text: 'Grupos'),
            Tab(text: 'Artilheiros'),
            Tab(text: 'Seleções'),
            Tab(text: 'Estádios'),
          ],
        ),
      ),
      body: Consumer<Copa2026Provider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFFD700)),
                  SizedBox(height: 12),
                  Text('Carregando dados...',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, color: Colors.white38, size: 48),
                  const SizedBox(height: 12),
                  const Text('Erro ao carregar dados',
                      style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: provider.load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black),
                  ),
                ],
              ),
            );
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _TodayTab(provider: provider),
              _ScheduleTab(provider: provider),
              _GroupsTab(provider: provider),
              _ScorersTab(provider: provider),
              _TeamsTab(provider: provider),
              _StadiumsTab(provider: provider),
            ],
          );
        },
      ),
    );
  }
}

// ── Tab: Hoje ─────────────────────────────────────────────────────────────────

class _TodayTab extends StatelessWidget {
  final Copa2026Provider provider;
  const _TodayTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final label =
        DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(today);
    final todayMatches = provider.todayMatches;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ),
        if (todayMatches.isEmpty) ...[
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A472A).withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('⚽', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Nenhum jogo hoje',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('A Copa começa em 11/06/2026',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Próximos jogos:',
                style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
          ...provider.nextDaysMatches.map((m) => MatchCard(
                match: m,
                show2026Actions: true,
                onTap: () => _openDetail(context, m),
              )),
        ] else
          ...todayMatches.map((m) => MatchCard(
                match: m,
                show2026Actions: true,
                onTap: () => _openDetail(context, m),
              )),
      ],
    );
  }

  void _openDetail(BuildContext context, Match m) {
    Navigator.push(context,
        MaterialPageRoute(
            builder: (_) =>
                MatchDetailScreen(match: m, show2026Actions: true)));
  }
}

// ── Tab: Agenda ───────────────────────────────────────────────────────────────

class _ScheduleTab extends StatelessWidget {
  final Copa2026Provider provider;
  const _ScheduleTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Match>>{};
    for (final m in provider.matches) {
      grouped.putIfAbsent(m.date, () => []).add(m);
    }
    final dates = grouped.keys.toList()..sort();

    return ListView.builder(
      itemCount: dates.length,
      itemBuilder: (ctx, i) {
        final date = dates[i];
        final matches = grouped[date]!;
        final dt = DateTime.tryParse(date);
        final label = dt != null
            ? DateFormat("EEE, dd/MM", 'pt_BR').format(dt)
            : date;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('${matches.length} jogos',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            ...matches.map((m) => MatchCard(
                  match: m,
                  show2026Actions: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MatchDetailScreen(match: m, show2026Actions: true),
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }
}

// ── Tab: Grupos ───────────────────────────────────────────────────────────────

class _GroupsTab extends StatelessWidget {
  final Copa2026Provider provider;
  const _GroupsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final groups = provider.groups;
    if (groups.isEmpty) {
      return const Center(
          child: Text('Carregando grupos...',
              style: TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: groups.length,
      itemBuilder: (ctx, i) {
        final group = groups[i];
        final standings = provider.getGroupStandings(group.name);

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF131F13),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A472A),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Text(
                          group.name.replaceAll('Group ', ''),
                          style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      TeamNamesPt.group(group.name),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Row(
                  children: const [
                    SizedBox(width: 26),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text('Seleção',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 10))),
                    _CellH('PJ'),
                    _CellH('V'),
                    _CellH('E'),
                    _CellH('D'),
                    _CellH('GP', width: 24),
                    _CellH('GC', width: 24),
                    _CellH('SG', width: 28),
                    _CellH('PTS', width: 30),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ...standings.asMap().entries.map((entry) {
                final idx = entry.key;
                final s = entry.value;
                final qualified = idx < 2;
                final flag = TeamFlags.get(s['team'] as String);

                return Container(
                  decoration: BoxDecoration(
                    color: qualified
                        ? const Color(0xFF1A472A).withValues(alpha: 0.25)
                        : null,
                    borderRadius: idx == standings.length - 1
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(13))
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        child: Text('${idx + 1}',
                            style: TextStyle(
                                color: qualified
                                    ? const Color(0xFFFFD700)
                                    : Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 22,
                        child: Text(
                          flag.isNotEmpty ? flag : (s['flag'] as String? ?? ''),
                          style: const TextStyle(fontSize: 17),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            TeamNamesPt.translate(s['team'] as String),
                            style: TextStyle(
                                color: qualified
                                    ? Colors.white
                                    : Colors.white60,
                                fontSize: 12,
                                fontWeight: qualified
                                    ? FontWeight.w600
                                    : FontWeight.normal),
                            overflow: TextOverflow.ellipsis),
                      ),
                      _CellD('${s['pj']}'),
                      _CellD('${s['v']}'),
                      _CellD('${s['e']}'),
                      _CellD('${s['d']}'),
                      _CellD('${s['gp']}', width: 24),
                      _CellD('${s['gc']}', width: 24),
                      _CellD('${s['sg']}', width: 28),
                      _CellD('${s['pts']}',
                          width: 30,
                          bold: true,
                          color: qualified
                              ? const Color(0xFFFFD700)
                              : Colors.white54),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ── Tab: Artilheiros ──────────────────────────────────────────────────────────

class _ScorersTab extends StatelessWidget {
  final Copa2026Provider provider;
  const _ScorersTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final scorers = provider.topScorers;

    if (scorers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('⚽', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('Ainda sem gols registrados.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Os artilheiros aparecerão após os primeiros jogos.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: scorers.length,
      itemBuilder: (ctx, i) {
        final s = scorers[i];
        final name = s['name'] as String;
        final goals = s['goals'] as int;
        final team = s['team'] as String;
        final penalties = s['penalties'] as int;
        final flag = TeamFlags.get(team);
        final teamPt = TeamNamesPt.translate(team);

        final medal = i == 0
            ? '🥇'
            : i == 1
                ? '🥈'
                : i == 2
                    ? '🥉'
                    : '${i + 1}º';

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: i < 3
                ? const Color(0xFF1A472A).withValues(alpha: 0.3)
                : const Color(0xFF131F13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: i == 0
                  ? const Color(0xFFFFD700).withValues(alpha: 0.4)
                  : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(medal,
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(width: 8),
              Text(flag.isNotEmpty ? flag : '🏳️',
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text(teamPt,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$goals ⚽',
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  if (penalties > 0)
                    Text('$penalties pen.',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tab: Estádios ─────────────────────────────────────────────────────────────

class _StadiumsTab extends StatelessWidget {
  final Copa2026Provider provider;
  const _StadiumsTab({required this.provider});

  static const _countryOrder = ['mx', 'us', 'ca'];
  static const _countryNames = {
    'us': 'Estados Unidos',
    'mx': 'México',
    'ca': 'Canadá',
  };

  @override
  Widget build(BuildContext context) {
    final byCountry = <String, List<Stadium>>{};
    for (final s in provider.stadiums) {
      byCountry.putIfAbsent(s.cc ?? 'us', () => []).add(s);
    }

    if (byCountry.isEmpty) {
      return const Center(
        child: Text('Carregando estádios...',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 10),
      children: _countryOrder
          .where((cc) => byCountry.containsKey(cc))
          .map((cc) => _CountryStadiums(
                cc: cc,
                name: _countryNames[cc] ?? cc.toUpperCase(),
                stadiums: byCountry[cc]!,
              ))
          .toList(),
    );
  }
}

class _CountryStadiums extends StatelessWidget {
  final String cc;
  final String name;
  final List<Stadium> stadiums;
  const _CountryStadiums(
      {required this.cc, required this.name, required this.stadiums});

  @override
  Widget build(BuildContext context) {
    final totalCapacity = stadiums.fold(0, (sum, s) => sum + s.capacity);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131F13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1A3A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Text(
                  cc == 'us'
                      ? '🇺🇸'
                      : cc == 'mx'
                          ? '🇲🇽'
                          : '🇨🇦',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Text(name,
                    style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const Spacer(),
                Text(
                  '${stadiums.length} estádio${stadiums.length > 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.people_outline,
                    color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Capacidade total: ${_fmt(totalCapacity)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          ...stadiums.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final isLast = i == stadiums.length - 1;
            return Container(
              decoration: BoxDecoration(
                border: i > 0
                    ? const Border(top: BorderSide(color: Colors.white12))
                    : null,
                borderRadius: isLast
                    ? const BorderRadius.vertical(bottom: Radius.circular(13))
                    : null,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A472A).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('🏟️', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.city,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people,
                              color: Color(0xFFFFD700), size: 12),
                          const SizedBox(width: 3),
                          Text(
                            _fmt(s.capacity),
                            style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.timezone,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return '${k == k.truncateToDouble() ? k.toInt() : k.toStringAsFixed(0)}k';
    }
    return n.toString();
  }
}

class _CellH extends StatelessWidget {
  final String text;
  final double width;
  const _CellH(this.text, {this.width = 26});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _CellD extends StatelessWidget {
  final String text;
  final double width;
  final bool bold;
  final Color color;
  const _CellD(this.text,
      {this.width = 26, this.bold = false, this.color = Colors.white60});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight:
                  bold ? FontWeight.bold : FontWeight.normal)),
    );
  }
}

// ── Tab: Seleções ─────────────────────────────────────────────────────────────

class _TeamsTab extends StatelessWidget {
  final Copa2026Provider provider;
  const _TeamsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final byConfed = <String, List<dynamic>>{};
    for (final t in provider.teams) {
      byConfed.putIfAbsent(t.confed, () => []).add(t);
    }
    final confeds = byConfed.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: confeds.length,
      itemBuilder: (ctx, i) {
        final confed = confeds[i];
        final teams = byConfed[confed]!;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF131F13),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A3A1A),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.public,
                        color: Color(0xFFFFD700), size: 16),
                    const SizedBox(width: 8),
                    Text(confed,
                        style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const Spacer(),
                    Text('${teams.length} seleções',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              ...teams.asMap().entries.map((entry) {
                final idx = entry.key;
                final t = entry.value;
                final rawName = t.displayName as String;
                final flag = TeamFlags.get(rawName);
                final namePt = TeamNamesPt.translate(rawName);
                final isLast = idx == teams.length - 1;

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: isLast
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(13))
                        : null,
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A472A).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          flag.isNotEmpty ? flag : t.flagIcon as String,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    title: Text(namePt,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                    subtitle: Text(
                      '${TeamNamesPt.continent(t.continent)}  •  Grupo ${t.group}  •  ${t.fifaCode}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A472A).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t.group as String,
                        style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TeamProfileScreen(teamName: rawName),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
