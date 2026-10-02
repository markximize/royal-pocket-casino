# Audio and branding

## Original audio palette

The game synthesizes its short sound effects at startup. `src/platform/sound_design.lua` owns the recipes; `src/platform/audio.lua` owns LÖVE playback. No recordings, downloaded assets, music loops, external audio dependencies or gameplay randomness are involved.

Card placement and flipping use deterministic filtered noise for a dry paper texture. Chips use short damped resonances with small fixed variations. Bet increases and decreases have different chip pitches. Collecting a positive payout has a brief layered chip sound. Interface movement uses a quiet click. Win, loss, push and bust have subdued distinct tones; a winning natural Blackjack has three short ascending notes. These are original synthetic cues, rather than recordings of physical casino equipment.

The established event names `card`, `flip`, `chips`, `button`, `win`, `loss` and `push` remain supported. Added names are `chip_up`, `chip_down`, `payout`, `blackjack`, `navigation` and `bust`. A result cue is queued only after the filtered presentation has finished revealing the committed result. Split Ace+10 uses the ordinary win cue. Two naturals use push. Mixed split outcomes follow the round's net result; bust feedback applies when every player hand busts and the round loses. Payout collection applies to positive net results, rather than a refunded stake or an even split result.

## Resource and playback limits

The fixed palette caches nineteen mono sources at 16 kHz and 16-bit sample depth. Its nominal decoded PCM payload is 90,976 bytes; actual LÖVE/OpenAL memory overhead has not been measured. Every cue lasts at most 420 ms and fades at both ends. No sound data or source is created during playback. Paper and chip variants rotate in a fixed order, separate from shoe RNG.

Playback permits at most four simultaneous voices. Short shared cooldowns limit repeated interface, paper, chip and result sounds. A result or collection cue may replace an older lower-priority cue after animation fast-forward. A busy source is otherwise allowed to finish. Sound off or volume zero stops active voices when applied through playback; application settings should also call `audio.stop` immediately when muting. The saved volume scale remains 0–10. Missing audio support leaves gameplay operational.

## Verification and rights

Automated checks cover finite sample values, quiet amplitude bounds, duration/fades, deterministic variation, no ambient RNG calls, cached allocation counts, volume/mute behavior, cooldowns, voice limits and result visibility. These checks cannot establish perceived audio quality, speaker distortion, real latency or hardware compatibility. Listen on desktop and RG35XX H at low and normal volume, test headphones where available, rapidly navigate/change bets, mute mid-cue and play both animated and reduced-motion results before approving the sound balance.

All effects are generated from project-authored formulas. There are no third-party audio assets to redistribute. Source and generated-output licensing remains subject to the owner's licensing decision; this change does not select or imply a public license.

## Supplied branding and credits

The main menu and About/Credits page display the owner-supplied logo at `assets/royal-pocket-casino-logo.png`. The image is loaded once and scaled proportionally for the 640×480 screen; the source PNG is not cropped, redrawn or recolored. No forced splash screen delays access to the menu. A 1280×1280 RGBA texture has a nominal uncompressed pixel payload of 6,553,600 bytes; actual runtime overhead has not been measured.

The menu keeps eight readable entries, including Learn Hi-Lo. About/Credits belongs in Settings so it does not crowd the main menu. Credits show the current application version from the save-schema version constant and the exact line `© 2026 MarkXimize Interactive`. This copyright display does not resolve the separate source, asset, brand or trademark licensing decisions.

About/Credits summarizes the known LÖVE, Bitstream Vera and JSON decoder licenses. Subsequent pages wrap and display the complete bundled notice files at a readable size, rather than replacing those files with a summary. The runtime notice describes the verified Windows distribution; it does not establish the dependency rights of an independently installed handheld runtime. The owner-supplied image's provenance and redistribution permission must be recorded before a public release; supplying an image for this private build does not automatically select its public license.

The tutorial screen presents the model's five stages, fifteen pages and fixed public-card exercises. It shows no hidden card ID, performs no count calculations or scoring, and provides the same labeled actions to controller and pointer users. Tutorial completion hands control to the existing Beginner Count Trainer rather than creating a separate practice engine.
