import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/match.dart';
import '../models/local_result.dart';

class ScoreEntryDialog extends StatefulWidget {
  final Match match;
  final LocalResult? existingResult;

  const ScoreEntryDialog({
    super.key,
    required this.match,
    this.existingResult,
  });

  @override
  State<ScoreEntryDialog> createState() => _ScoreEntryDialogState();
}

class _ScoreEntryDialogState extends State<ScoreEntryDialog> {
  late TextEditingController _ctrl1;
  late TextEditingController _ctrl2;

  @override
  void initState() {
    super.initState();
    _ctrl1 = TextEditingController(
      text: widget.existingResult?.score1.toString() ?? '',
    );
    _ctrl2 = TextEditingController(
      text: widget.existingResult?.score2.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: const Color(0xFF202020),
      title: Text(
        '${widget.match.team1} x ${widget.match.team2}',
        style: const TextStyle(color: Colors.white, fontSize: 16),
        textAlign: TextAlign.center,
      ),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ScoreInput(controller: _ctrl1, label: widget.match.team1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('X',
                style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ),
          _ScoreInput(controller: _ctrl2, label: widget.match.team2),
        ],
      ),
      actions: [
        if (widget.existingResult != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop('delete'),
            child: const Text('Apagar', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            final s1 = int.tryParse(_ctrl1.text);
            final s2 = int.tryParse(_ctrl2.text);
            if (s1 == null || s2 == null) return;
            Navigator.of(context).pop([s1, s2]);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _ScoreInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _ScoreInput({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        SizedBox(
          width: 60,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF2A3D2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFFFD700)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF4A6A4A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFFFD700), width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            ),
          ),
        ),
      ],
    );
  }
}
