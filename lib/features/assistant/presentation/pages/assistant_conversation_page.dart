import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/privacy/financial_privacy_controller.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_conversation.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_summary.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_voice.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_conversation_controller.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_summary_provider.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_voice_controller.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';

class AssistantConversationPage extends ConsumerStatefulWidget {
  const AssistantConversationPage({this.autoStart = false, super.key});

  /// Só é verdadeiro quando a rota veio do atalho global de conversa.
  final bool autoStart;

  @override
  ConsumerState<AssistantConversationPage> createState() =>
      _AssistantConversationPageState();
}

class _AssistantConversationPageState
    extends ConsumerState<AssistantConversationPage>
    with WidgetsBindingObserver {
  late final AssistantConversationController _conversation;
  late final AssistantVoiceController _voice;
  AssistantDeterministicSummary? _summary;
  bool _isForeground = true;
  bool _conversationEnabled = false;
  bool _activationInProgress = false;

  @override
  void initState() {
    super.initState();
    _conversation = ref.read(assistantConversationControllerProvider.notifier);
    _voice = ref.read(assistantVoiceControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_requestVoiceStart());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopForExit(clearVoice: true));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (!_isForeground) unawaited(_stopForExit());
  }

  Future<void> _stopForExit({bool clearVoice = false}) async {
    _conversationEnabled = false;
    await _conversation.interrupt();
    await _voice.interrupt(
      clearVoice
          ? AssistantVoiceInterruption.financialPrivacy
          : AssistantVoiceInterruption.appInactive,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthUser?>>(authStateProvider, (previous, next) {
      if (previous?.value?.id != next.value?.id) {
        unawaited(_stopForExit(clearVoice: true));
      }
    });
    ref.listen<bool>(financialPrivacyControllerProvider, (previous, next) {
      if (previous == true && !next) unawaited(_stopForExit(clearVoice: true));
    });
    ref.listen<AssistantVoiceState>(assistantVoiceControllerProvider, (
      AssistantVoiceState? previous,
      AssistantVoiceState next,
    ) {
      if (previous?.phase != AssistantVoicePhase.completed &&
          next.phase == AssistantVoicePhase.completed) {
        unawaited(_resumeListeningAfterSpeech());
      }
    });
    final bool valuesVisible = ref.watch(financialPrivacyControllerProvider);
    final ProfileGateState? gate = ref
        .watch(profileGateControllerProvider)
        .value;
    final bool consent =
        gate is ProfileGateValid && gate.profile.aiConsentEnabled;
    final AssistantConversationState state = ref.watch(
      assistantConversationControllerProvider,
    );
    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) unawaited(_stopForExit(clearVoice: true));
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF101418),
        appBar: AppBar(
          backgroundColor: const Color(0xFF101418),
          foregroundColor: Colors.white,
          title: const Text('Modo de conversa'),
          actions: <Widget>[
            IconButton(
              tooltip: valuesVisible ? 'Ocultar valores' : 'Mostrar valores',
              onPressed: () => ref
                  .read(financialPrivacyControllerProvider.notifier)
                  .toggle(),
              icon: Icon(
                valuesVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth <= 360;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact
                      ? AppSpacing.compactPageHorizontal
                      : AppSpacing.pageHorizontal,
                  AppSpacing.md,
                  compact
                      ? AppSpacing.compactPageHorizontal
                      : AppSpacing.pageHorizontal,
                  AppSpacing.xxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(height: constraints.maxHeight * .32),
                        _ConversationVisual(
                          phase: state.phase,
                          voiceIntensity: state.voiceIntensity,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Semantics(
                          liveRegion: true,
                          label: 'Estado do modo de conversa: ${state.message}',
                          child: _ConversationStatus(state: state),
                        ),
                        if (state.transcript.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          _TranscriptCard(transcript: state.transcript),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        if (!consent)
                          _BlockedCard(
                            icon: Icons.lock_outline,
                            message:
                                'Ative o consentimento do Assistente antes de usar perguntas por voz.',
                            onPressed: () =>
                                context.push(AppRoutes.privacyConsents),
                            label: 'Configurar consentimento',
                          )
                        else if (!valuesVisible)
                          _BlockedCard(
                            icon: Icons.visibility_off_outlined,
                            message:
                                'A privacidade financeira interrompe microfone e leitura em voz. Mostre os dados para continuar.',
                            onPressed: () => ref
                                .read(
                                  financialPrivacyControllerProvider.notifier,
                                )
                                .toggle(),
                            label: 'Mostrar dados',
                          )
                        else
                          _VoiceAction(
                            state: state,
                            onActivate: _requestVoiceStart,
                            onStop: _stopForExit,
                          ),
                        if (_summary != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          _ConversationAnswer(summary: _summary!),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.keyboard_outlined),
                          label: const Text('Usar perguntas por texto'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'O áudio não é gravado, salvo ou enviado. A transcrição existe apenas nesta tela e é apagada ao sair. Este modo apenas consulta resumos confirmados; nunca altera dados financeiros.',
                          style: TextStyle(color: Color(0xFFD5DEE7)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _requestVoiceStart() async {
    if (_activationInProgress || !_isForeground) return;
    if (!ref.read(financialPrivacyControllerProvider)) {
      await _conversation.activate(canUseVoice: false);
      return;
    }
    _activationInProgress = true;
    try {
      final bool hasPermission = await _conversation.hasMicrophonePermission();
      if (!mounted) return;
      if (!hasPermission) {
        final bool? accepted = await _showMicrophoneExplanation();
        if (accepted != true || !mounted) return;
      }
      _conversationEnabled = true;
      await _listenAndAnswer();
    } finally {
      _activationInProgress = false;
    }
  }

  Future<bool?> _showMicrophoneExplanation() => showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Usar microfone nesta conversa?'),
      content: const Text(
        'O microfone será usado apenas para reconhecer sua pergunta enquanto esta tela estiver aberta e o aplicativo estiver em primeiro plano. Nenhum áudio é gravado, salvo ou enviado.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Agora não'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Permitir e ouvir'),
        ),
      ],
    ),
  );

  Future<void> _listenAndAnswer() async {
    if (!_conversationEnabled || !_isForeground || !mounted) return;
    final bool valuesVisible = ref.read(financialPrivacyControllerProvider);
    await _conversation.activate(canUseVoice: valuesVisible);
    if (!mounted || !_conversationEnabled || !valuesVisible) return;
    final AssistantConversationState state = ref.read(
      assistantConversationControllerProvider,
    );
    final AssistantGuidedQuestion? question = state.question;
    if (question == null) return;
    final AssistantReadModel model = ref.read(assistantReadModelProvider);
    final AssistantDeterministicSummary summary =
        AssistantDeterministicSummaryBuilder.build(
          question: question,
          snapshot: model.snapshot,
        );
    setState(() => _summary = summary);
    if (!summary.isAvailable) {
      _conversation.noConfirmedAnswer();
      return;
    }
    await _voice.setEnabled(true, valuesVisible: true);
    if (!_conversationEnabled || !_isForeground || !mounted) return;
    _conversation.speaking();
    await _voice.speak(
      AssistantSpeechFormatter.format(summary),
      valuesVisible: true,
    );
  }

  Future<void> _resumeListeningAfterSpeech() async {
    if (_activationInProgress ||
        !_conversationEnabled ||
        !_isForeground ||
        !mounted ||
        !ref.read(financialPrivacyControllerProvider)) {
      return;
    }
    _activationInProgress = true;
    try {
      await _listenAndAnswer();
    } finally {
      _activationInProgress = false;
    }
  }
}

class _VoiceAction extends StatelessWidget {
  const _VoiceAction({
    required this.state,
    required this.onActivate,
    required this.onStop,
  });
  final AssistantConversationState state;
  final VoidCallback onActivate;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final bool listening =
        state.phase == AssistantConversationPhase.listening ||
        state.phase == AssistantConversationPhase.requestingPermission;
    return FilledButton.icon(
      key: const ValueKey<String>('assistant-voice-mode-action'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSpacing.minimumTapTarget),
      ),
      onPressed: listening ? () => unawaited(onStop()) : onActivate,
      icon: Icon(
        listening ? Icons.stop_circle_outlined : Icons.mic_none_outlined,
      ),
      label: Text(listening ? 'Parar microfone' : 'Ativar modo de voz'),
    );
  }
}

class _ConversationVisual extends StatefulWidget {
  const _ConversationVisual({
    required this.phase,
    required this.voiceIntensity,
  });
  final AssistantConversationPhase phase;
  final double voiceIntensity;

  @override
  State<_ConversationVisual> createState() => _ConversationVisualState();
}

class _ConversationVisualState extends State<_ConversationVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _animation.stop();
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
    return Semantics(
      label: 'Núcleo visual do assistente: ${_phaseLabel(widget.phase)}',
      child: SizedBox(
        height: 190,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (BuildContext context, Widget? _) => CustomPaint(
            painter: _ConversationCorePainter(
              progress: reduceMotion ? 0 : _animation.value,
              phase: widget.phase,
              voiceIntensity: widget.voiceIntensity,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _ConversationCorePainter extends CustomPainter {
  const _ConversationCorePainter({
    required this.progress,
    required this.phase,
    required this.voiceIntensity,
  });
  final double progress;
  final AssistantConversationPhase phase;
  final double voiceIntensity;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double fallback = switch (phase) {
      AssistantConversationPhase.listening =>
        .42 + math.sin(progress * math.pi * 4).abs() * .25,
      AssistantConversationPhase.thinking => .16,
      AssistantConversationPhase.speaking => .32,
      _ => 1,
    };
    final double reactiveIntensity = voiceIntensity > 0
        ? voiceIntensity
        : fallback;
    final double intensity = 1 + reactiveIntensity * .24;
    final double pulse =
        1 + math.sin(progress * math.pi * 2) * .055 * intensity;
    final Paint glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFFB7E8FF).withValues(alpha: .95),
          const Color(0xFF317B9F).withValues(alpha: .32),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 70 * pulse));
    canvas.drawCircle(center, 70 * pulse, glow);
    canvas.drawCircle(
      center,
      20 * pulse,
      Paint()..color = const Color(0xFFBFEAFF),
    );
    canvas.drawCircle(
      center,
      11 * pulse,
      Paint()..color = const Color(0xFFEBF8FF),
    );
    for (
      int index = 0;
      index < AssistantConversationVisualConfig.particleCount;
      index++
    ) {
      final double direction = index.isEven ? 1 : -1;
      final double velocity = .28 + (index % 7) * .11;
      final double phaseOffset = index * 2.399963229728653;
      final double angle =
          progress * math.pi * 2 * velocity * direction + phaseOffset;
      final double baseRadius = 40 + (index % 6) * 12.0;
      final double drift = math.sin(
        progress * math.pi * 2 * (.18 + (index % 5) * .07) + phaseOffset,
      );
      final double radius = baseRadius + drift * 7 + reactiveIntensity * 9;
      final Offset particle =
          center +
          Offset(
            math.cos(angle) * radius,
            math.sin(angle + drift * .16) * radius * (.42 + (index % 3) * .04),
          );
      canvas.drawCircle(
        particle,
        1.7 + (index % 4) * .45,
        Paint()
          ..color = const Color(0xFF87CBE8).withValues(
            alpha: .38 + (index % 5) * .08 + reactiveIntensity * .12,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_ConversationCorePainter old) =>
      old.progress != progress ||
      old.phase != phase ||
      old.voiceIntensity != voiceIntensity;
}

class _ConversationStatus extends StatelessWidget {
  const _ConversationStatus({required this.state});
  final AssistantConversationState state;
  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Text(
        _phaseLabel(state.phase),
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: Colors.white),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        state.message,
        style: const TextStyle(color: Color(0xFFD5DEE7)),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.transcript});
  final String transcript;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF1B252D),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Transcrição desta sessão',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(transcript, style: const TextStyle(color: Color(0xFFD5DEE7))),
        ],
      ),
    ),
  );
}

class _ConversationAnswer extends StatelessWidget {
  const _ConversationAnswer({required this.summary});
  final AssistantDeterministicSummary summary;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF1B252D),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            summary.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            summary.observation,
            style: const TextStyle(color: Color(0xFFD5DEE7)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Fontes e período: ${summary.periodLabel}',
            style: const TextStyle(color: Color(0xFFB7E8FF)),
          ),
        ],
      ),
    ),
  );
}

class _BlockedCard extends StatelessWidget {
  const _BlockedCard({
    required this.icon,
    required this.message,
    required this.onPressed,
    required this.label,
  });
  final IconData icon;
  final String message;
  final VoidCallback onPressed;
  final String label;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF1B252D),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: <Widget>[
          Icon(icon, color: const Color(0xFFB7E8FF)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: const TextStyle(color: Color(0xFFD5DEE7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: onPressed, child: Text(label)),
        ],
      ),
    ),
  );
}

String _phaseLabel(AssistantConversationPhase phase) => switch (phase) {
  AssistantConversationPhase.ready => 'Pronto',
  AssistantConversationPhase.requestingPermission => 'Preparando microfone',
  AssistantConversationPhase.listening => 'Ouvindo',
  AssistantConversationPhase.thinking => 'Pensando',
  AssistantConversationPhase.speaking => 'Falando',
  AssistantConversationPhase.unavailable => 'Reconhecimento indisponível',
  AssistantConversationPhase.permissionDenied => 'Microfone não autorizado',
  AssistantConversationPhase.failed => 'Não foi possível reconhecer',
};
