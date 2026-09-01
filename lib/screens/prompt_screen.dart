import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../services/batch_parser.dart';
import '../theme/theme.dart';

/// The imperium LLM prompt: a persona + strict JSON envelope. Copy it into
/// any AI, paste the activity, and it returns rows ready for batch import.
class PromptScreen extends StatelessWidget {
  const PromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: t.scaffoldBackgroundColor,
        foregroundColor: t.colorScheme.onSurface,
        elevation: 0,
        title: const Text('LLM PROMPT',
            style: TextStyle(fontFamily: AppType.monument, letterSpacing: 2)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'From chat to ledger in one paste. Give your AI this prompt plus '
            'a one-line activity; it returns a JSON envelope you import in one shot.',
            style: t.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          Text('THE PROMPT', style: t.textTheme.labelSmall),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _persona(t),
                  style: const TextStyle(
                    fontFamily: AppType.ledger,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: t.colorScheme.primary,
              foregroundColor: t.colorScheme.onPrimary,
            ),
            onPressed: () => _copy(context, _persona(t)),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy full prompt'),
          ),
          const SizedBox(height: 24),

          Text('QUICK STARTERS', style: t.textTheme.labelSmall),
          const SizedBox(height: 8),
          for (final tmpl in kBatchTemplates)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: t.colorScheme.outline),
                ),
                onPressed: () => _copy(context, _filled(tmpl)),
                child: Text(tmpl.name, style: const TextStyle(fontFamily: AppType.ledger)),
              ),
            ),
          const SizedBox(height: 24),

          Text('CATEGORIES', style: t.textTheme.labelSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in kCategories)
                Chip(
                  label: Text(c.replaceAll('-', ' ')),
                  backgroundColor: t.colorScheme.surfaceContainerHighest,
                  side: BorderSide(color: t.colorScheme.outlineVariant),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _persona(ThemeData t) => kBatchPromptTemplate
      .replaceAll('{PASTE_ACTIVITY}', '<describe your day or activity>');

  String _filled(BatchTemplate tmpl) {
    final p = kBatchPromptTemplate.replaceAll('{PASTE_ACTIVITY}', tmpl.activityPrompt);
    return p;
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prompt copied. Paste it into your AI to get the envelope.')),
    );
  }
}
