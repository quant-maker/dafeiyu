import 'package:feiyu/voice/call_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('callNext happy path', () {
    test('start enters listening and asks for the mic', () {
      final t = callNext(CallPhase.off, CallEvent.start);
      expect(t.phase, CallPhase.listening);
      expect(t.intent, CallIntent.startListening);
      expect(t.intents, <CallIntent>[CallIntent.startListening]);
    });

    test('final transcript stops listening and sends the text', () {
      final t = callNext(CallPhase.listening, CallEvent.transcriptReady);
      expect(t.phase, CallPhase.thinking);
      expect(t.intents, <CallIntent>[
        CallIntent.stopListening,
        CallIntent.sendTranscript,
      ]);
    });

    test('reply text done starts speaking', () {
      final t = callNext(CallPhase.thinking, CallEvent.replyTextDone);
      expect(t.phase, CallPhase.speaking);
      expect(t.intent, CallIntent.speakReply);
    });

    test('speech done reopens the mic', () {
      final t = callNext(CallPhase.speaking, CallEvent.speechDone);
      expect(t.phase, CallPhase.listening);
      expect(t.intent, CallIntent.startListening);
    });

    test('full loop walks off -> listening -> thinking -> speaking -> listening',
        () {
      var phase = CallPhase.off;
      phase = callNext(phase, CallEvent.start).phase;
      expect(phase, CallPhase.listening);
      phase = callNext(phase, CallEvent.transcriptReady).phase;
      expect(phase, CallPhase.thinking);
      phase = callNext(phase, CallEvent.replyTextDone).phase;
      expect(phase, CallPhase.speaking);
      phase = callNext(phase, CallEvent.speechDone).phase;
      expect(phase, CallPhase.listening);
    });

    test('silence while listening keeps listening with no intent', () {
      final t = callNext(CallPhase.listening, CallEvent.heardSilence);
      expect(t.phase, CallPhase.listening);
      expect(t.intent, isNull);
      expect(t.intents, isEmpty);
    });
  });

  group('hangup', () {
    for (final phase in CallPhase.values) {
      test('hangup from ${phase.name} turns everything off', () {
        final t = callNext(phase, CallEvent.hangup);
        expect(t.phase, CallPhase.off);
        expect(t.intents, <CallIntent>[
          CallIntent.stopListening,
          CallIntent.stopSpeaking,
        ]);
      });
    }
  });

  group('failure', () {
    for (final phase in <CallPhase>[
      CallPhase.listening,
      CallPhase.thinking,
      CallPhase.speaking,
      CallPhase.error,
    ]) {
      test('failed from ${phase.name} lands in error with no intent', () {
        final t = callNext(phase, CallEvent.failed);
        expect(t.phase, CallPhase.error);
        expect(t.intent, isNull);
        expect(t.intents, isEmpty);
      });
    }

    test('failed while already off is ignored', () {
      final t = callNext(CallPhase.off, CallEvent.failed);
      expect(t.phase, CallPhase.off);
      expect(t.intent, isNull);
    });
  });

  group('invalid events', () {
    test('transcriptReady while thinking is ignored without throwing', () {
      late CallTransition t;
      expect(
        () => t = callNext(CallPhase.thinking, CallEvent.transcriptReady),
        returnsNormally,
      );
      expect(t.phase, CallPhase.thinking);
      expect(t.intents, isEmpty);
    });

    test('speechDone while listening is ignored without throwing', () {
      late CallTransition t;
      expect(
        () => t = callNext(CallPhase.listening, CallEvent.speechDone),
        returnsNormally,
      );
      expect(t.phase, CallPhase.listening);
      expect(t.intents, isEmpty);
    });

    test('replyTextDone while off is ignored without throwing', () {
      late CallTransition t;
      expect(
        () => t = callNext(CallPhase.off, CallEvent.replyTextDone),
        returnsNormally,
      );
      expect(t.phase, CallPhase.off);
      expect(t.intent, isNull);
    });
  });
}
