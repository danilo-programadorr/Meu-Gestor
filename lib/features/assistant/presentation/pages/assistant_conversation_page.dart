// Responsabilidade: apresenta o modo de conversa acessível, alternando voz e
// texto enquanto encerra recursos ao sair ou perder primeiro plano.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/privacy/financial_privacy_controller.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_conversation.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_remote_integration.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_voice.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_conversation_consent_controller.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_conversation_controller.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_remote_consent_controller.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_remote_conversation_controller.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_voice_controller.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/widgets/assistant_remote_answer_panel.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';

/// Tela autenticada do modo de conversa; nunca inicia serviço em segundo plano.
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
  late final AssistantConversationConsentController _consent;
  late final AssistantRemoteConversationController _remoteConversation;
  late final AssistantVoiceController _voice;
  bool _isForeground = true;
  bool _conversationEnabled = false;
  bool _activationInProgress = false;
  bool _consentPromptOpen = false;
  bool _consentChecked = false;
  final TextEditingController _textController = TextEditingController();
  bool _textMode = false;

  @override
  void initState() {
    super.initState();
    _conversation = ref.read(assistantConversationControllerProvider.notifier);
    _consent = ref.read(
      assistantConversationConsentControllerProvider.notifier,
    );
    _remoteConversation = ref.read(
      assistantRemoteConversationControllerProvider.notifier,
    );
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
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (!_isForeground) unawaited(_stopForExit());
  }

  Future<void> _stopForExit({
    bool clearVoice = false,
    bool discardRemoteAnswer = true,
  }) async {
    _conversationEnabled = false;
    _textController.clear();
    if (discardRemoteAnswer) _remoteConversation.discard();
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
      if (previous == true && !next) {
        _remoteConversation.blockForFinancialPrivacy();
        unawaited(_stopForExit(clearVoice: true, discardRemoteAnswer: false));
      }
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
    ref.listen<AssistantConversationConsentState>(
      assistantConversationConsentControllerProvider,
      (
        AssistantConversationConsentState? previous,
        AssistantConversationConsentState next,
      ) {
        if (next.requiresDecision) unawaited(_showConsentPrompt());
      },
    );
    final bool valuesVisible = ref.watch(financialPrivacyControllerProvider);
    final ProfileGateState? gate = ref
        .watch(profileGateControllerProvider)
        .value;
    final bool consent =
        gate is ProfileGateValid && gate.profile.aiConsentEnabled;
    final AssistantConversationConsentState consentState = ref.watch(
      assistantConversationConsentControllerProvider,
    );
    final bool effectiveRemoteConsent = consent && consentState.isReady;
    if (gate case ProfileGateValid(:final profile)) {
      _scheduleConsentCheck(profile);
    }
    final AssistantConversationState state = ref.watch(
      assistantConversationControllerProvider,
    );
    final AssistantRemoteConversationState remoteState = ref.watch(
      assistantRemoteConversationControllerProvider,
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
                        const SizedBox(height: AppSpacing.md),
                        if (!effectiveRemoteConsent)
                          const _ConsentPendingCard()
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
                        else if (!_textMode)
                          _VoiceAction(
                            state: state,
                            onActivate: _requestVoiceStart,
                            onStop: _stopForExit,
                          ),
                        if (_textMode &&
                            state.transcript.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          AssistantRemoteAnswerPanel(state: remoteState),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        if (_textMode &&
                            effectiveRemoteConsent &&
                            valuesVisible)
                          AssistantTextQuestionInput(
                            controller: _textController,
                            onSend: _submitText,
                          )
                        else if (!_textMode &&
                            effectiveRemoteConsent &&
                            valuesVisible)
                          OutlinedButton.icon(
                            key: const ValueKey<String>(
                              'assistant-use-text-action',
                            ),
                            onPressed: _useTextMode,
                            icon: const Icon(Icons.keyboard_outlined),
                            label: const Text('Usar perguntas por texto'),
                          ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'O app não persiste o áudio do microfone. No modo de voz, a transcrição é descartada antes da resposta. Depois da validação financeira, somente o texto aprovado é enviado ao Google Gemini-TTS e a voz retornada é reproduzida sem mostrar a resposta escrita. Se a voz neural estiver indisponível, o Android pode usar a voz local. Este modo nunca altera dados financeiros.',
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
    if (!await _ensureEffectiveRemoteConsent()) return;
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

  Future<void> _useTextMode() async {
    await _stopForExit(discardRemoteAnswer: false);
    if (mounted) setState(() => _textMode = true);
  }

  Future<void> _submitText() async {
    if (!_isForeground || !ref.read(financialPrivacyControllerProvider)) {
      _textController.clear();
      return;
    }
    if (!await _ensureEffectiveRemoteConsent()) return;
    final String question = _textController.text;
    _textController.clear();
    final int? conversationOperation = await _conversation.submitText(question);
    if (!mounted) return;
    final String message = ref
        .read(assistantConversationControllerProvider)
        .transcript;
    if (message.isEmpty || conversationOperation == null) return;
    // A conclusão visual pertence ao mesmo handle monotônico da pergunta;
    // sucesso, indisponibilidade e exceção encerram “Pensando” sem apagar o card.
    await _conversation.awaitTextRemoteOperation(
      operation: conversationOperation,
      request: () => _requestRemoteAnswer(message),
    );
  }

  /// Envia somente a pergunta já validada pelo modo atual. O backend continua
  /// responsável pelo contexto, pela evidência e pela resposta segura.
  Future<void> _requestRemoteAnswer(
    String message, {
    bool voiceOnly = false,
  }) async {
    if (!_isForeground) return;
    if (!await _ensureEffectiveRemoteConsent()) return;
    if (!mounted) return;
    await _remoteConversation.requestGroundedAnswer(
      message: message,
      aiConsentEnabled: _aiConsentEnabled,
      remoteContextConsentAllowed: ref.read(
        assistantRemoteConsentControllerProvider,
      ),
      financialValuesVisible: ref.read(financialPrivacyControllerProvider),
      voiceOnly: voiceOnly,
    );
  }

  bool get _aiConsentEnabled {
    final ProfileGateState? gate = ref
        .read(profileGateControllerProvider)
        .value;
    return gate is ProfileGateValid && gate.profile.aiConsentEnabled;
  }

  void _scheduleConsentCheck(UserProfile profile) {
    if (_consentChecked) return;
    _consentChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_consent.check(aiConsentEnabled: profile.aiConsentEnabled));
      }
    });
  }

  Future<bool> _ensureEffectiveRemoteConsent() async {
    final ProfileGateState? gate = ref
        .read(profileGateControllerProvider)
        .value;
    if (gate is! ProfileGateValid) return false;
    await _consent.check(aiConsentEnabled: gate.profile.aiConsentEnabled);
    return ref.read(assistantConversationConsentControllerProvider).isReady;
  }

  Future<void> _showConsentPrompt() async {
    if (_consentPromptOpen || !mounted) return;
    _consentPromptOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => Consumer(
        builder: (BuildContext _, WidgetRef ref, Widget? child) {
          final AssistantConversationConsentState state = ref.watch(
            assistantConversationConsentControllerProvider,
          );
          return AssistantConversationConsentDialog(
            state: state,
            onActivate: () async {
              final ProfileGateState? currentGate = ref
                  .read(profileGateControllerProvider)
                  .value;
              if (currentGate is! ProfileGateValid) return;
              await _consent.activate(profile: currentGate.profile);
              if (!dialogContext.mounted ||
                  !ref
                      .read(assistantConversationConsentControllerProvider)
                      .isReady) {
                return;
              }
              Navigator.of(dialogContext).pop();
            },
            onDecline: () {
              _consent.decline();
              Navigator.of(dialogContext).pop();
            },
          );
        },
      ),
    );
    _consentPromptOpen = false;
  }

  Future<bool?> _showMicrophoneExplanation() => showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Usar microfone nesta conversa?'),
      content: const Text(
        'O microfone será usado apenas para reconhecer sua pergunta enquanto esta tela estiver aberta e o aplicativo estiver em primeiro plano. O app não grava nem persiste o áudio; o serviço de reconhecimento configurado no Android pode processá-lo para produzir a transcrição temporária.',
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
    final String message = state.transcript;
    if (message.isEmpty) return;
    _conversation.clearTranscript();
    await _requestRemoteAnswer(message, voiceOnly: true);
    if (!_conversationEnabled || !_isForeground || !mounted) return;
    final AssistantRemoteConversationState remoteState = ref.read(
      assistantRemoteConversationControllerProvider,
    );
    await _voice.setEnabled(true, valuesVisible: true);
    if (!_conversationEnabled || !_isForeground || !mounted) return;
    _conversation.speaking();
    if (remoteState.audio case final AssistantRemoteAudio audio) {
      await _voice.playAudio(audio.bytes, valuesVisible: true);
    } else {
      await _voice.speak(
        remoteState.response?.answer ?? remoteState.message,
        valuesVisible: true,
      );
    }
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

class AssistantTextQuestionInput extends StatelessWidget {
  const AssistantTextQuestionInput({
    super.key,
    required this.controller,
    required this.onSend,
  });

  final TextEditingController controller;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF1B252D),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('assistant-text-question-field'),
            controller: controller,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => unawaited(onSend()),
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'Ex.: Qual é meu saldo?',
              filled: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const ValueKey<String>('assistant-text-send-action'),
            onPressed: () => unawaited(onSend()),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Enviar'),
          ),
        ],
      ),
    ),
  );
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
    duration: AssistantConversationVisualConfig.pulseDuration,
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
    final double phaseEnergy = switch (phase) {
      AssistantConversationPhase.listening =>
        .58 + math.sin(progress * math.pi * 6).abs() * .18,
      AssistantConversationPhase.thinking => .42,
      AssistantConversationPhase.speaking => .68,
      _ => .2,
    };
    final double reactiveIntensity = voiceIntensity > 0
        ? voiceIntensity
        : phaseEnergy;
    final double heartbeat = _heartbeat(progress);
    final double pulse = 1 + heartbeat * (.08 + reactiveIntensity * .05);
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
      18 * pulse,
      Paint()..color = const Color(0xFFBFEAFF),
    );
    canvas.drawCircle(
      center,
      9 * pulse,
      Paint()..color = const Color(0xFFEBF8FF),
    );

    // Ondas concêntricas propagam o mesmo impulso do núcleo como uma descarga
    // curta; cada anel desaparece antes de alcançar a borda do campo visual.
    for (
      int ring = 0;
      ring < AssistantConversationVisualConfig.pulseRingCount;
      ring++
    ) {
      final double wave = (progress + ring / 4) % 1;
      final double radius = 24 + wave * 70;
      final double opacity = (1 - wave) * (.24 + reactiveIntensity * .16);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 - wave * .65
          ..color = const Color(0xFF8EDCFF).withValues(alpha: opacity),
      );
    }

    for (
      int index = 0;
      index < AssistantConversationVisualConfig.particleCount;
      index++
    ) {
      final double phaseOffset = index * 2.399963229728653;
      final double shell = index % 9;
      final double electricJitter = math.sin(
        progress * math.pi * 12 + phaseOffset * 1.7,
      );
      final double radius =
          30 +
          shell * 7.2 +
          heartbeat * (4 + reactiveIntensity * 5) +
          electricJitter * 1.8;
      final double angle =
          phaseOffset + math.sin(progress * math.pi * 2 + shell * .37) * .055;
      final Offset particle =
          center +
          Offset(
            math.cos(angle) * radius,
            math.sin(angle) * radius * (.46 + (index % 4) * .025),
          );
      final double particleRadius =
          AssistantConversationVisualConfig.minimumParticleRadius +
          (index % 5) /
              4 *
              (AssistantConversationVisualConfig.maximumParticleRadius -
                  AssistantConversationVisualConfig.minimumParticleRadius);
      canvas.drawCircle(
        particle,
        particleRadius,
        Paint()
          ..color = const Color(0xFF87CBE8).withValues(
            alpha:
                .24 +
                (index % 6) * .055 +
                heartbeat * .16 +
                reactiveIntensity * .08,
          ),
      );
    }
  }

  double _heartbeat(double value) {
    final double first = math.exp(-math.pow((value - .18) / .055, 2));
    final double second = .72 * math.exp(-math.pow((value - .31) / .07, 2));
    return math.min(1, first + second);
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

class _ConsentPendingCard extends StatelessWidget {
  const _ConsentPendingCard();

  @override
  Widget build(BuildContext context) => const Card(
    color: Color(0xFF1B252D),
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Text(
        'O Assistente Financeiro permanece desativado nesta conversa. Escolha uma opção no aviso para liberar perguntas remotas.',
        style: TextStyle(color: Color(0xFFD5DEE7)),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class AssistantConversationConsentDialog extends StatelessWidget {
  const AssistantConversationConsentDialog({
    required this.state,
    required this.onActivate,
    required this.onDecline,
    super.key,
  });

  final AssistantConversationConsentState state;
  final Future<void> Function() onActivate;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ativar Assistente Financeiro'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Para responder nesta conversa, o Assistente precisa do seu consentimento geral para IA e da permissão canônica para contexto financeiro remoto.',
        ),
        if (state.message case final String message) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: state.isActivating ? null : onDecline,
        child: const Text('Agora não'),
      ),
      FilledButton(
        key: const ValueKey<String>('assistant-consent-activate-action'),
        onPressed: state.isActivating ? null : () => unawaited(onActivate()),
        child: state.isActivating
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Ativar e continuar'),
      ),
    ],
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
