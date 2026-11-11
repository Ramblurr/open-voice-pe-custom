# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Open Voice PE is an overlay package on top of the official Home Assistant Voice Preview Edition firmware (ESP32-S3). It removes on-device wake word detection in favour of streaming audio to Home Assistant (openWakeWord runs there), routes TTS responses to a remote assist_satellite or media_player, and keeps follow-up conversations working on every route.

## Build Commands

```bash
# Validate the merged config (fast, needs network for the upstream package)
esphome config demo.yaml

# Compile the firmware
esphome compile demo.yaml

# Upload to device
esphome upload demo.yaml

# View logs
esphome logs demo.yaml
```

## Architecture

- `open-voice-pe.yaml` pulls the upstream firmware as a pinned package (`packages.upstream.ref`) and layers changes on top. Users include it from their own device config.
- `demo.yaml` is a sample device config: substitutions, WiFi, and `!extend` of the TTS target selects.
- There is no on-device `micro_wake_word`. `voice_assistant.use_wake_word` is true and the device streams continuously.

### Package merge rules that shape this file

ESPHome merges package layers from the highest priority down. Consequences:

- A dict key under a hub (for example `voice_assistant.on_tts_start`) can be removed with `!remove` or appended to (automation lists concatenate), but not removed and redefined under the same name across layers.
- List items with ids can be removed (`- id: !remove x`) or extended (`- id: !extend x`), and two `!extend` entries for the same id apply in order, so an extend that `!remove`s a key followed by one that redefines it works.
- All pure removals live in the inline `open_voice_pe_removals` package. Replacement behaviour is attached to different hooks (`api.on_client_connected`, `voice_assistant.on_tts_end`) or to a second `!extend`.

### Conversation flow

1. `api.on_client_connected` runs `resume_listening`, which waits for the voice assistant subscription and starts streaming.
2. `voice_assistant.on_tts_end` receives the TTS URL in `x`, sets `tts_playback_pending`, and routes to a satellite (`assist_satellite.announce`, completion via `on_success`), a media player (`media_player.play_media` plus `tts_media_player_resume_delay`), or the local speaker (await `media_player.is_announcing`).
3. `tts_playback_finished` clears the flag and runs `resume_listening`. `voice_assistant.on_end` only resumes when nothing is pending.
4. The ESPHome component keeps a private continue-conversation flag from the last intent and drops the wake word flag on the next start when it is set. `on_error` calls `voice_assistant.stop` for non wake word errors to clear a stale flag; never call `voice_assistant.stop` on the remote path after TTS end.

## Reference Materials

- `/home/ramblurr/src/github.com/esphome/home-assistant-voice-pe` - upstream firmware clone with full history and tags
- `extra/home-assistant-voice-pe/` - older upstream snapshot
- `extra/esphome-docs/` - ESPHome documentation (offline reference)
- `extra/ha-core/` - Home Assistant core, see `homeassistant/components/esphome/assist_satellite.py` and `manager.py`
- `assist_satellite.markdown` / `media_player.markdown` - HA integration docs
