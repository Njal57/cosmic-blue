# cosmic-blue branding

## Logo

The "orbit c": an open orbit around a planet, with a moon in the gap. The
wordmark is Montserrat Light, stored as outlines in `logo/glyphs.json` so the
SVGs need no font.

- `logo/cosmic-blue-logo.svg`: the mark (installed as the `cosmic-blue-logo` icon)
- `logo/cosmic-blue-logo.png`: the mark, 512 px (Artifact Hub)
- `logo/cosmic-blue-logo-horizontal-dark.svg` / `-light.svg`: mark + wordmark,
  for dark and light backgrounds
- `system_files/usr/share/plymouth/themes/spinner/watermark.png`: the dark
  horizontal logo at 392x70, shown on the boot screen

Regenerate the SVGs with `python3 logo/build.py`.

## Wallpaper

`system_files/usr/share/backgrounds/cosmic-blue/cosmic-blue.jpg` (5120x2880),
the default COSMIC wallpaper. Keep the main elements inside the centre so they
survive cropping to 16:10, 4:3 and 21:9.

It is built from two layers:

- `wallpaper/sky.py`: sky gradient, procedural Milky Way and stars (numpy)
- `wallpaper/foreground.py`: the logo as a scene, a planet inside a glowing
  open orbit with a moon in the gap (SVG, rendered by `wallpaper/render.js`
  with Playwright's Chromium)

`wallpaper/build.sh` renders both, dims the sky behind the planet, adds a fine grain against banding and
writes the JPEG. The output is deterministic (fixed seeds).
