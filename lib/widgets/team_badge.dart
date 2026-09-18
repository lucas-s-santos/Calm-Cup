import 'package:flutter/material.dart';
import '../utils/club_crests.dart';
import '../utils/team_flags.dart';

/// Decide o visual de um time num único lugar: bandeira de emoji (seleção
/// nacional — Copa do Mundo/Euro), escudo real (clube de uma das 6 ligas
/// europeias, única fonte de escudo real gratuita disponível hoje) ou um
/// badge de iniciais gerado localmente (fallback universal — Champions
/// League, Brasileirão, Libertadores, Copa América, ou qualquer nome sem
/// bandeira/escudo conhecido).
class TeamBadge extends StatelessWidget {
  final String teamName;
  final String? competitionId;
  final double size;

  const TeamBadge({
    super.key,
    required this.teamName,
    this.competitionId,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    final flag = TeamFlags.get(teamName);
    if (flag.isNotEmpty) {
      return Text(flag, style: TextStyle(fontSize: size));
    }

    final crestUrls =
        competitionId != null ? ClubCrests.urlsFor(competitionId!, teamName) : const <String>[];
    if (crestUrls.isEmpty) {
      return _InitialsBadge(teamName: teamName, size: size);
    }

    return _CrestWithFallback(
      urls: crestUrls,
      size: size,
      fallback: _InitialsBadge(teamName: teamName, size: size),
    );
  }
}

/// Tenta cada URL candidata em ordem até uma carregar; se todas falharem,
/// mostra o [fallback] (badge de iniciais). Necessário porque o nome do
/// openfootball às vezes bate direto com o arquivo da fonte de escudos e às
/// vezes só bate depois de tirar o "FC" do fim — `Image.network` só aceita
/// uma URL por vez, então quem tenta a próxima da lista é este widget.
class _CrestWithFallback extends StatefulWidget {
  final List<String> urls;
  final double size;
  final Widget fallback;
  const _CrestWithFallback(
      {required this.urls, required this.size, required this.fallback});

  @override
  State<_CrestWithFallback> createState() => _CrestWithFallbackState();
}

class _CrestWithFallbackState extends State<_CrestWithFallback> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.urls.length) return widget.fallback;

    return Image.network(
      widget.urls[_index],
      key: ValueKey(widget.urls[_index]),
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _index++);
        });
        return SizedBox(width: widget.size, height: widget.size);
      },
    );
  }
}

class _InitialsBadge extends StatelessWidget {
  final String teamName;
  final double size;
  const _InitialsBadge({required this.teamName, required this.size});

  static const _palette = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFF16A34A),
    Color(0xFF0891B2),
    Color(0xFFCA8A04),
    Color(0xFF4F46E5),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colorFor(teamName),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initialsOf(teamName),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _colorFor(String name) => _palette[name.hashCode.abs() % _palette.length];

  String _initialsOf(String name) {
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final longest = words.reduce((a, b) => a.length >= b.length ? a : b);
    final letters = longest.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
    if (letters.isEmpty) return '?';
    return letters.substring(0, letters.length >= 3 ? 3 : letters.length).toUpperCase();
  }
}
