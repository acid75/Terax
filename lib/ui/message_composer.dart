import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../sharing/shared_message.dart';
import '../sharing/link_opener.dart';
import '../theme/terax_theme.dart';
import 'components/terax_components.dart';

Future<SharedMessage?> showMessageComposer(
  BuildContext context, {
  String? initial,
}) => showDialog<SharedMessage>(
  context: context,
  builder: (_) => _Composer(initial: initial),
);

class _Composer extends StatefulWidget {
  const _Composer({this.initial});
  final String? initial;
  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  late final TextEditingController input = TextEditingController(
    text: widget.initial,
  );
  late SharedMessageKind kind =
      SharedMessage.validLink(widget.initial?.trim() ?? '') == null
      ? SharedMessageKind.text
      : SharedMessageKind.link;
  String? error;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void accept() {
    try {
      final value = kind == SharedMessageKind.text
          ? SharedMessage.text(input.text)
          : SharedMessage.link(input.text);
      value.encode();
      Navigator.pop(context, value);
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    return AlertDialog(
      title: const Text('Texto y enlaces'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: TeraxSize.settingsWidth),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TeraxSegmentedControl<SharedMessageKind>(
                segments: const [
                  TeraxSegment(
                    value: SharedMessageKind.text,
                    icon: Icons.notes,
                    label: 'Texto',
                  ),
                  TeraxSegment(
                    value: SharedMessageKind.link,
                    icon: Icons.link,
                    label: 'Enlace',
                  ),
                ],
                selected: kind,
                onChanged: (v) => setState(() => kind = v),
              ),
              const SizedBox(height: TeraxSpace.s16),
              TextField(
                controller: input,
                minLines: kind == SharedMessageKind.link ? 1 : 4,
                maxLines: kind == SharedMessageKind.link ? 3 : 10,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: kind == SharedMessageKind.text
                      ? 'Escribe tu mensaje'
                      : 'https://ejemplo.com',
                  errorText: error,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    try {
                      final data = await Clipboard.getData(
                        Clipboard.kTextPlain,
                      );
                      if (mounted && data?.text != null) {
                        setState(() {
                          input.text = data!.text!;
                          error = null;
                        });
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => error =
                              'No se pudo leer el portapapeles. Puedes escribir el mensaje.',
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Pegar del portapapeles'),
                ),
              ),
              Text(
                'Se envía cuando confirmas. Los enlaces se abren al pulsarlos en el equipo receptor.',
                style: TeraxText.caption.copyWith(color: c.textMuted),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TeraxPrimaryButton(
          label: 'Continuar',
          icon: Icons.arrow_forward,
          onPressed: accept,
        ),
      ],
    );
  }
}

class MessagePreview extends StatelessWidget {
  const MessagePreview({
    super.key,
    required this.message,
    this.compact = false,
  });
  final SharedMessage message;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(TeraxRadius.lg),
      child: Padding(
        padding: EdgeInsets.all(compact ? TeraxSpace.s8 : TeraxSpace.s20),
        child: compact
            ? Icon(
                message.kind == SharedMessageKind.link
                    ? Icons.link
                    : Icons.notes,
                color: c.mint,
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      message.kind == SharedMessageKind.link
                          ? Icons.link
                          : Icons.notes,
                      color: c.mint,
                    ),
                    const SizedBox(height: TeraxSpace.s12),
                    Text(message.label, style: TeraxText.label),
                    const SizedBox(height: TeraxSpace.s12),
                    SelectableText(message.text, style: TeraxText.body),
                  ],
                ),
              ),
      ),
    );
  }
}

class MessageActions extends StatelessWidget {
  const MessageActions({super.key, required this.message});
  final SharedMessage message;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: TeraxSpace.s8,
    runSpacing: TeraxSpace.s8,
    children: [
      TeraxPrimaryButton(
        label: 'Copiar',
        icon: Icons.copy,
        onPressed: () async {
          var feedback = 'Copiado al portapapeles';
          try {
            await Clipboard.setData(ClipboardData(text: message.text));
          } catch (_) {
            feedback = 'No se pudo copiar. Intenta de nuevo.';
          }
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(feedback)));
          }
        },
      ),
      if (message.uri != null)
        OutlinedButton.icon(
          onPressed: () async {
            final opened = await LinkOpener.open(message.uri!);
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No se pudo abrir el enlace. Puedes copiarlo.'),
                ),
              );
            }
          },
          icon: const Icon(Icons.open_in_new),
          label: const Text('Abrir enlace'),
        ),
    ],
  );
}
