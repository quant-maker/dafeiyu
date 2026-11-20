/// Pure, hardware-free state machine for the hands-free call loop.
///
/// The widget layer feeds events in and performs the side effects described by
/// the returned [CallTransition]. Keeping this pure makes the tricky
/// half-duplex ordering testable without a microphone or speaker.
library;

enum CallPhase { off, listening, thinking, speaking, error }

enum CallEvent {
  start,
  heardSilence,
  transcriptReady,
  replyTextDone,
  speechDone,
  failed,
  hangup,
}

/// What the widget layer must do in response to an event.
enum CallIntent {
  startListening,
  stopListening,
  sendTranscript,
  speakReply,
  stopSpeaking,
}

class CallTransition {
  const CallTransition(
    this.phase, {
    this.intent,
    this.intents = const <CallIntent>[],
  });

  final CallPhase phase;

  /// Primary intent (first of [intents] when several are required).
  final CallIntent? intent;

  /// Full ordered set of side effects. Some events need more than one,
  /// e.g. a final transcript both closes the mic and sends the text.
  final List<CallIntent> intents;
}

/// The core reducer. Unknown / out-of-phase events are ignored: the phase is
/// echoed back unchanged and no intent is emitted. It never throws.
CallTransition callNext(CallPhase phase, CallEvent event) {
  switch (event) {
    case CallEvent.start:
      return const CallTransition(
        CallPhase.listening,
        intent: CallIntent.startListening,
        intents: <CallIntent>[CallIntent.startListening],
      );
    case CallEvent.hangup:
      return const CallTransition(
        CallPhase.off,
        intent: CallIntent.stopListening,
        intents: <CallIntent>[
          CallIntent.stopListening,
          CallIntent.stopSpeaking,
        ],
      );
    case CallEvent.failed:
      if (phase == CallPhase.off) return CallTransition(phase);
      return const CallTransition(CallPhase.error);
    case CallEvent.transcriptReady:
      if (phase != CallPhase.listening) return CallTransition(phase);
      return const CallTransition(
        CallPhase.thinking,
        intent: CallIntent.sendTranscript,
        intents: <CallIntent>[
          CallIntent.stopListening,
          CallIntent.sendTranscript,
        ],
      );
    case CallEvent.replyTextDone:
      if (phase != CallPhase.thinking) return CallTransition(phase);
      return const CallTransition(
        CallPhase.speaking,
        intent: CallIntent.speakReply,
        intents: <CallIntent>[CallIntent.speakReply],
      );
    case CallEvent.speechDone:
      if (phase != CallPhase.speaking) return CallTransition(phase);
      return const CallTransition(
        CallPhase.listening,
        intent: CallIntent.startListening,
        intents: <CallIntent>[CallIntent.startListening],
      );
    case CallEvent.heardSilence:
      // The recogniser restarts itself; stay where we are.
      return CallTransition(phase);
  }
}

/// Thin object wrapper around [callNext] for callers that prefer a class.
class CallFlow {
  const CallFlow();

  CallTransition next(CallPhase phase, CallEvent event) =>
      callNext(phase, event);
}
