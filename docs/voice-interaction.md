# Voice-First Development

## The idea

The primary interaction mode is voice. The developer speaks; the system listens, transcribes, and acts. Keyboard input is secondary, used for code review, approval, and situations where precision matters more than speed.

This isn't about voice commands ("run tests", "commit"). It's about natural conversation with an intelligent agent: describing what you want to build, discussing architecture, reviewing progress, giving feedback. The same conversation you'd have with a senior colleague, but with an agent that can also execute.


## Architecture

The voice pipeline has three stages:

```
Speech-to-Text (STT) -> LLM (text-to-text) -> Text-to-Speech (TTS)
```

### Speech-to-text

The STT component should run locally for privacy and latency. Current preference: NVIDIA Parakeet multilingual model via Super Whisper (macOS). The model should be shared between the dictation app and the agentic system where possible to avoid duplicate memory usage.

Requirements:
- Low latency (real-time transcription, not batch)
- Good accuracy with technical vocabulary (code terms, library names)
- Ability to handle mixed-language input (e.g., English/French)
- Runs on-device without cloud round-trips

### LLM layer

The orchestrator agent processes transcribed text. It must handle:
- Transcription errors (homophones, missing punctuation, run-on sentences, repeated words)
- Intent over literal text (act on what the developer likely said, not the imperfect transcription)
- Mixed-language input with English output
- Ambient noise rejection (conversations nearby, cafe background)

The LLM should be the smartest model available for the synchronous conversation. This is where response quality matters most.

### Text-to-speech

TTS is lower priority than STT and LLM quality. A lightweight, low-resource TTS is preferable because compute should go to agents. High-fidelity voice synthesis is not needed for development work. Clear and understandable is sufficient.

Different agent roles could use different TTS voices so the developer can tell by ear who's speaking. The orchestrator, a researcher, and a test runner would each have a distinct voice.

The system should work as an audio-only interface when needed. The developer can walk around, no screen required. Like a phone call with an assistant who happens to be able to write code.

### Voice infrastructure

LiveKit is the candidate for the audio communication layer. It handles transport (WebRTC, room management, audio routing) while leaving STT and TTS to the local pipeline. Running LiveKit locally in a Docker container keeps the audio loop on the local network for low latency.

This also opens up remote access: calling in from a phone to interact with agents, queue tasks, or check on progress. The LiveKit cloud offering could bridge the gap between local and remote without changing the agent-side architecture.


## Hardware considerations

Voice processing competes with agent workloads for local compute.

On a 128GB M3 Max (primary target):
- STT model: should be lightweight relative to the machine's capacity
- TTS: minimal resource usage
- Remaining capacity: reserved for agent model inference and Docker workloads

On a 64GB M1 Max (secondary target):
- Same priorities, but tighter budget. STT model choice may need to be smaller.

The voice pipeline should be configurable to different hardware profiles. Don't hardcode model choices.


## Interaction model

The developer's physical setup:
- Voice input via push-to-talk (e.g., Option+Space in Super Whisper)
- Optional: gesture controls via wearable (e.g., ring device for enter, escape, mode switching)
- Screen for visual output (code, dashboards) but not required for all interactions
- The system controls a dashboard and can surface visuals on request

Key design decision: no voice-triggered command words. Saying "submit" should not submit something. The cognitive overhead of remembering which words are "magic" is too high. Voice is for conversation; explicit actions happen through gestures or keyboard.
