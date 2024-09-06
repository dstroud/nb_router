# nb_router
Mod to route notes to multiple Nota Bene voices

### Installation
Install via maiden: `;install https://github.com/dstroud/nb_router`

Enable the mod via SYSTEM>>MODS>>NB_ROUTER>>E3 and restart


### Usage
Select `router` as the voice/player in your NB-capable script. Then configure using PARAMETERS>>EDIT>>router

There are four modes to select from:

- mult
    - Sends the same note and velocity to the selected voices.

- mix
    - Provides a crossfader-style param to adjust the mix of voice 1/2.
- x-over
    - Transitions from voice 1 to voice 2 depending on note/pitch.
    - `x-over note` sets the mid-point of the transition from voice 1 to voice 2.
    - `x-over width` determines the width or smoothness of the transition in semitones. A value of 0 will instantly switch from voice 1 to 2 at the crossover note whereas a value of 12 will gradually transition over the span of one octave, etc...
    - `x-over overlap` allows for more or less overlap between voices during the transition.
    - `voice 1/2 floor` sets a minimum velocity threshold (as percentage of original velocity) so that the voice never completely fades out.
- rotate
    - Alternates between voices.
