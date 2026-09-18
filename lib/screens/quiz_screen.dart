import 'dart:math';
import 'package:flutter/material.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final List<_QuizQuestion> _questions = [];
  int _current = 0;
  int _score = 0;
  String? _selected;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _questions.addAll(_buildQuestions());
    _questions.shuffle(Random());
    if (_questions.length > 10) {
      _questions.removeRange(10, _questions.length);
    }
  }

  List<_QuizQuestion> _buildQuestions() {
    return [
      _QuizQuestion(
        question: 'Qual país ganhou a Copa do Mundo de 2022?',
        options: ['França', 'Brasil', 'Argentina', 'Alemanha'],
        correct: 'Argentina',
      ),
      _QuizQuestion(
        question: 'Quantas vezes o Brasil ganhou a Copa do Mundo?',
        options: ['3 vezes', '4 vezes', '5 vezes', '6 vezes'],
        correct: '5 vezes',
      ),
      _QuizQuestion(
        question: 'Qual foi o primeiro país a ganhar duas Copas seguidas?',
        options: ['Brasil', 'Itália', 'Alemanha', 'Argentina'],
        correct: 'Itália',
      ),
      _QuizQuestion(
        question: 'Em que país foi realizada a Copa de 2014?',
        options: ['Argentina', 'Brasil', 'Alemanha', 'África do Sul'],
        correct: 'Brasil',
      ),
      _QuizQuestion(
        question: 'Quem foi o artilheiro da Copa de 2018?',
        options: ['Messi', 'Ronaldo', 'Harry Kane', 'Mbappé'],
        correct: 'Harry Kane',
      ),
      _QuizQuestion(
        question: 'Qual país sediou a primeira Copa do Mundo (1930)?',
        options: ['Brasil', 'Argentina', 'Uruguai', 'Itália'],
        correct: 'Uruguai',
      ),
      _QuizQuestion(
        question: 'Quantas seleções participam da Copa 2026?',
        options: ['32', '40', '48', '64'],
        correct: '48',
      ),
      _QuizQuestion(
        question: 'Em quais países será realizada a Copa 2026?',
        options: [
          'Brasil, Argentina, Uruguai',
          'EUA, México, Canadá',
          'Espanha, Portugal, Marrocos',
          'EUA, Brasil, México'
        ],
        correct: 'EUA, México, Canadá',
      ),
      _QuizQuestion(
        question: 'Quem ganhou a Copa do Mundo de 1970 no México?',
        options: ['Itália', 'Alemanha', 'Brasil', 'Argentina'],
        correct: 'Brasil',
      ),
      _QuizQuestion(
        question: 'Qual é o recorde de gols em uma única Copa do Mundo?',
        options: ['141 gols', '161 gols', '171 gols', '201 gols'],
        correct: '171 gols',
      ),
      _QuizQuestion(
        question: 'Qual país ganhou a Copa de 2010 na África do Sul?',
        options: ['Holanda', 'Alemanha', 'Brasil', 'Espanha'],
        correct: 'Espanha',
      ),
      _QuizQuestion(
        question: 'Quantos grupos tem a Copa do Mundo 2026?',
        options: ['8 grupos', '10 grupos', '12 grupos', '16 grupos'],
        correct: '12 grupos',
      ),
    ];
  }

  void _answer(String option) {
    if (_selected != null) return;
    final correct = _questions[_current].correct;
    setState(() {
      _selected = option;
      if (option == correct) _score++;
    });

    Future.delayed(const Duration(seconds: 1, milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _selected = null;
        if (_current + 1 >= _questions.length) {
          _finished = true;
        } else {
          _current++;
        }
      });
    });
  }

  void _restart() {
    setState(() {
      _questions.shuffle(Random());
      _current = 0;
      _score = 0;
      _selected = null;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('🧠 Quiz Copa do Mundo',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _finished ? _buildResult() : _buildQuestion(),
    );
  }

  Widget _buildQuestion() {
    if (_questions.isEmpty) {
      return const Center(
        child: Text('Sem perguntas disponíveis',
            style: TextStyle(color: Colors.white54)),
      );
    }

    final q = _questions[_current];
    final progress = (_current + 1) / _questions.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progresso
          Row(
            children: [
              Text('${_current + 1}/${_questions.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFF202020),
                    color: const Color(0xFFFFD700),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$_score pts',
                  style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 32),
          // Pergunta
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              q.question,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          // Opções
          ...q.options.map((opt) {
            Color? bgColor;
            Color borderColor = Colors.white24;
            Color textColor = Colors.white;

            if (_selected != null) {
              if (opt == q.correct) {
                bgColor = Colors.green.withValues(alpha: 0.3);
                borderColor = Colors.green;
                textColor = Colors.greenAccent;
              } else if (opt == _selected) {
                bgColor = Colors.red.withValues(alpha: 0.25);
                borderColor = Colors.red;
                textColor = Colors.redAccent;
              }
            }

            return GestureDetector(
              onTap: () => _answer(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: bgColor ?? const Color(0xFF202020),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Text(opt,
                    style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final total = _questions.length;
    final pct = (_score / total * 100).round();
    final emoji = pct >= 80
        ? '🏆'
        : pct >= 60
            ? '⚽'
            : pct >= 40
                ? '😅'
                : '😬';
    final message = pct >= 80
        ? 'Você é um expert em Copa do Mundo!'
        : pct >= 60
            ? 'Muito bom! Você entende bem de futebol.'
            : pct >= 40
                ? 'Razoável. Continue estudando!'
                : 'Precisa estudar mais sobre a Copa!';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            Text(
              '$_score / $total',
              style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 48,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('$pct% de acerto',
                style: const TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.refresh),
                label: const Text('Jogar novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Voltar ao início',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizQuestion {
  final String question;
  final List<String> options;
  final String correct;

  _QuizQuestion({
    required this.question,
    required this.options,
    required this.correct,
  });
}
