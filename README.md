# svg-metadata: Add metadata to tags in Lilypond SVG output

This package adds metadata such as moment, duration and pitch to SVG tags when compiling Lilypond scores to SVG format. The code herein was written by [Mathieu Demange](https://gitlab.com/sigmate/) and repackaged into a [lyp](https://lyp.noteflakes.com) package. It was originally distributed as part of the [LilyPond HTML Live Score](https://gitlab.com/sigmate/lilypond-html-live-score).

## Installation

```bash
lyp install svg-metadata
```

## Usage

To add the SVG metadata, just require the package at the top of your Lilypond score source file:

```lilypond
\require "svg-metadata"
```

... and then compile to SVG:

```bash
$ lilypond -dbackend=svg myfile.ly
```

The `svg-metadata` package wraps each notation symbol with a `<g>` tag with the following attributes:

- `id` - a numerical id.
- `class` - class description of the symbol, e.g. `ly grob Stem` etc.
- `data-moment` - the moment of occurrence.
- `data-measure` - the measure number.
- `data-time` - the time of occurrence within the measure.

For notes and rests there are additional attributes:

- `data-time-end` - the time of occurrence of the note's end.
- `data-duration` - the duration of the note.
- `data-pitch` - the note's pitch, expressed as interval in semitones relative to middle C.

