# nb_router
Mod to route notes to multiple Nota Bene voices

### Installation
Install via maiden: `;install https://github.com/dstroud/nb_router`

Enable the mod via SYSTEM>>MODS>>NB_ROUTER>>E3 and restart


### Usage
Select `router` as the voice/player in your NB-capable script. Then configure using PARAMETERS>>EDIT>>router

There are four modes to select from:

- **MULT** - Sends the same note and velocity to the selected voices.

- **MIX** - Provides a crossfader-style param to adjust the mix of voice 1/2.
- **X-OVER** - Transitions from voice 1 to voice 2 depending on note/pitch.
    - `x-over note` sets the mid-point of the transition from voice 1 to voice 2.
    - `x-over width` determines the width or smoothness of the transition in semitones. A value of 0 will instantly switch from voice 1 to 2 at the crossover note whereas a value of 12 will gradually transition over the span of one octave, etc...
    - `x-over overlap` allows for more or less overlap between voices during the transition.
    - `voice 1/2 floor` sets a minimum velocity threshold (as percentage of original velocity) so that the voice never completely fades out.
- **ROTATE** - Alternates between voices.

### Ideas
- If you have two copies of a synth/voice with limited polyphony, `rotate` can be used to aggregate or extend polyphony. For example, summing the audio of two 6-voice hardware synths will result in a 12-voice synth.

- For processing engine/external voices with eurorack, `mult` to Crow. This provides v/oct and an envelope that can be used with modules like effects and VCAs for more dynamic processing (think pitch/keyboard tracking and envelope-based modulation).

- Add a sub oscillator using `mult`. Keep in mind that for near-simultaneous notes (i.e. chords), the last note is the one you'll usually hear, so chords may need to be played from highest to lowest pitch in your sequencer.

- Multing to two similar voices hard panned with some variation in voice parameters can result in a nice stereo effect.

- Use two instances of the same voice with different settings with `x-over` mode and a high `x-over width` setting for pitch/keyboard tracking-style effects

- `x-over` mode can be used to create a "keyboard split" (set `x-over width` to 0) so a single sequence can be split into distinct voices based on pitch range.

- Scripts that work with NB voice params (such as Dreamsequence) have access to all of nb_router's parameters, so try automating parameters like `mix`.
