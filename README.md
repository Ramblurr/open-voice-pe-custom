# Open Voice PE

Open Voice PE is a small overlay on top of the official [Home Assistant Voice Preview Edition](https://github.com/esphome/home-assistant-voice-pe) firmware. It keeps the official firmware intact, pins it to a release, and changes three things:

- Wake word detection happens in Home Assistant, not on the device. The device streams microphone audio to Home Assistant continuously and Home Assistant runs the wake word engine, for example the openWakeWord add-on. There is no microWakeWord on the device. The wake word is therefore whatever the Assist pipeline selected for the device uses.
- TTS responses can be routed to a remote `assist_satellite` or `media_player` entity instead of the device speaker. The targets are selects in Home Assistant that you fill per device.
- Follow-up conversations work on every route. The device resumes listening only after the response finished playing, and skips the wake word when the assistant asked for a follow-up.

Everything else, from the LED ring and the dial to timers, Sendspin and the physical controls, is the official firmware.

## Requirements

- ESPHome 2026.9.0 or newer.
- Home Assistant with the ESPHome integration, an Assist pipeline whose wake word stage uses a wake word engine running in Home Assistant, and "Allow the device to perform Home Assistant actions" enabled for the device.
- For remote TTS with follow-up conversations, a target that exposes an `assist_satellite` entity, for example [linux-voice-assistant](https://github.com/OHF-Voice/linux-voice-assistant).

## Setup

1. Copy `open-voice-pe.yaml` into your ESPHome config directory, for example as `common/open-voice-pe.yaml`.
2. Create a device config like `demo.yaml`. It has to define the substitutions `name`, `friendly_name` and `api_encryption_key`, include the overlay as a package, and provide the WiFi settings:

   ```yaml
   substitutions:
     name: voice-pe-kitchen
     friendly_name: voice-pe-kitchen
     api_encryption_key: !secret api_encryption_key

   packages:
     - !include common/open-voice-pe.yaml

   wifi:
     ssid: !secret wifi_ssid
     password: !secret wifi_password

   select:
     - id: !extend tts_target_satellite
       options:
         - assist_satellite.kitchen_announce_satellite_assist_satellite
     - id: !extend tts_target_media_player
       options:
         - media_player.kitchen_announce_satellite_media_player
   ```

3. Compile and upload with `esphome run voice-pe-kitchen.yaml`.
4. In Home Assistant, open the device, enable "Allow the device to perform Home Assistant actions", and pick the Assist pipeline under "Assistant". The wake word is configured on that pipeline.

## Entities added by the overlay

| Entity | Purpose |
| --- | --- |
| Use Satellite for TTS | On: send responses to the selected satellite. Off: send them to the selected media player, or play locally when that is "none". |
| TTS target satellite | `assist_satellite` entity that announces the response. |
| TTS target media player | `media_player` entity that plays the response. |
| Voice Assistant Enabled | Turns streaming to Home Assistant off entirely. |

## How a conversation flows

1. The device streams audio to Home Assistant, which detects the wake word and runs the pipeline.
2. At the end of TTS generation the device receives the audio URL and routes it. A satellite target gets `assist_satellite.announce`. Home Assistant blocks that call until playback finished, and the device waits for it to return. A media player target gets `media_player.play_media`, which only reports that playback started, so the device waits a fixed `tts_media_player_resume_delay` after that. The local speaker is awaited directly.
3. Once playback is done the device starts the voice assistant again. If the assistant asked for a follow-up, the ESPHome voice assistant component skips the wake word and keeps the conversation id. Otherwise it goes back to waiting for the wake word.

Two substitutions tune this: `tts_media_player_resume_delay` (default 3s) and `tts_playback_watchdog` (default 120s, the point at which the device resumes listening even if Home Assistant never reports completion).

## Updating the upstream firmware

The upstream release is pinned by `ref:` in the `packages:` block of `open-voice-pe.yaml`. To move to a new release, change the tag and recompile. The overlay only removes or appends to upstream keys, so most upstream changes merge without edits. If upstream renames one of the ids or keys the overlay touches, ESPHome fails validation and points at the key.

## License

MIT. See [LICENSE](LICENSE).
