import 'package:flutter/material.dart';

import '../app_colors.dart';
import 'verse_annotations_repository.dart';

/// Highlight, note, bookmark, or copy — returned when the user picks an action.
Future<String?> showVerseActionsSheet(
  BuildContext context, {
  required int verseNumber,
  String? subtitle,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Column(
                  children: [
                    Text(
                      'Verse $verseNumber',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const _VerseActionTile(
                value: 'Highlight',
                icon: Icons.highlight_outlined,
                label: 'Highlight',
              ),
              const _VerseActionTile(
                value: 'Note',
                icon: Icons.note_alt_outlined,
                label: 'Note',
              ),
              const _VerseActionTile(
                value: 'Bookmark',
                icon: Icons.bookmark_border,
                label: 'Bookmark',
              ),
              const _VerseActionTile(
                value: 'Copy',
                icon: Icons.copy_outlined,
                label: 'Copy',
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _VerseActionTile extends StatelessWidget {
  const _VerseActionTile({
    required this.value,
    required this.icon,
    required this.label,
  });

  final String value;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accentBlueDeep),
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      onTap: () => Navigator.of(context).pop(value),
    );
  }
}

/// Compact row of 7 highlight colours.
Future<int?> showHighlightColorPicker(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Highlight colour',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < VerseAnnotationsRepository.highlightColors.length; i++)
                    _ColorDot(
                      color: Color(VerseAnnotationsRepository.highlightColors[i]),
                      onTap: () => Navigator.of(ctx).pop(i),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12, width: 1),
          ),
        ),
      ),
    );
  }
}

class NoteEditorResult {
  const NoteEditorResult({required this.text, required this.isDraft});

  final String text;
  final bool isDraft;
}

/// Exercise-book style note editor. Returns null if closed with no text.
Future<NoteEditorResult?> showExerciseBookNoteEditor(
  BuildContext context, {
  String? initialText,
  bool initialDraft = false,
}) {
  return showModalBottomSheet<NoteEditorResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ExerciseBookNoteSheet(
      initialText: initialText,
      initialDraft: initialDraft,
    ),
  );
}

class _ExerciseBookNoteSheet extends StatefulWidget {
  const _ExerciseBookNoteSheet({
    this.initialText,
    this.initialDraft = false,
  });

  final String? initialText;
  final bool initialDraft;

  @override
  State<_ExerciseBookNoteSheet> createState() => _ExerciseBookNoteSheetState();
}

class _ExerciseBookNoteSheetState extends State<_ExerciseBookNoteSheet> {
  late final TextEditingController _controller;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close({required bool saveAsDraft}) {
    if (_saved) return;
    final text = _controller.text.trim();
    if (saveAsDraft && text.isNotEmpty) {
      Navigator.of(context).pop(NoteEditorResult(text: text, isDraft: true));
      return;
    }
    Navigator.of(context).pop(null);
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _saved = true);
    Navigator.of(context).pop(NoteEditorResult(text: text, isDraft: false));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4E8D0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD4C4A8), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFE8D9BC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => _close(saveAsDraft: true),
                  ),
                  const Spacer(),
                  if (widget.initialDraft)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        'Draft',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.brown.shade400,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Save note',
                    icon: Icon(
                      Icons.check_circle_rounded,
                      size: 28,
                      color: Colors.green.shade700,
                    ),
                    onPressed: _save,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0D0B8)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _LinedPaperPainter(),
                      ),
                    ),
                    TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.55,
                        color: Color(0xFF3D3428),
                        fontFamily: 'serif',
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.fromLTRB(14, 10, 14, 10),
                        hintText: 'Write your study note…',
                        hintStyle: TextStyle(
                          color: Color(0xFFB0A090),
                          fontFamily: 'serif',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinedPaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD8E8F4).withValues(alpha: 0.55)
      ..strokeWidth = 1;
    const lineHeight = 28.0;
    var y = lineHeight;
    while (y < size.height) {
      canvas.drawLine(Offset(12, y), Offset(size.width - 8, y), paint);
      y += lineHeight;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// View / add notes for one verse.
Future<void> showVerseNotesSheet(
  BuildContext context, {
  required int verseNum,
  required List<VerseNote> notes,
  required Future<void> Function() onAddNote,
  required Future<void> Function(VerseNote note) onEditNote,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFFF4E8D0),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Notes · Verse $verseNum',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: Color(0xFF3D3428),
                ),
              ),
              const SizedBox(height: 12),
              if (notes.isEmpty)
                Text(
                  'No notes yet.',
                  style: TextStyle(color: Colors.brown.shade400),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: notes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = notes[i];
                      return Material(
                        color: const Color(0xFFFFFDF7),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            await onEditNote(n);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (n.isDraft)
                                      Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Draft',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade900,
                                          ),
                                        ),
                                      ),
                                    const Spacer(),
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: Colors.brown.shade300,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  n.text,
                                  style: const TextStyle(
                                    height: 1.45,
                                    color: Color(0xFF3D3428),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await onAddNote();
                },
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add note'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4E37),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
