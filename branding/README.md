# cosmic-blue branding

## Logo

The "orbit c": an open orbit around a planet, with a moon in the gap. The
wordmark is Montserrat Light, stored as outlines in `logo/glyphs.json` so the
SVGs need no font.

- `logo/cosmic-blue-logo.svg`: the mark (installed as the `cosmic-blue-logo` icon)
- `logo/cosmic-blue-logo.png`: the mark, 512 px (Artifact Hub)
- `logo/cosmic-blue-logo-horizontal-dark.svg` / `-light.svg`: mark + wordmark,
  for dark and light backgrounds

## Boot screen

The `cosmic-blue` Plymouth theme, in
`system_files/usr/share/plymouth/themes/cosmic-blue/`. It is Fedora's BGRT
theme (the PC maker's logo from the firmware, for a flicker-free boot) with
our images:

- `bgrt-fallback.png`: the mark at 192x192, shown in the middle when the
  firmware has no logo (virtual machines, some PCs). Regenerate it with
  `node plymouth/render.js` (Playwright).
- `watermark.png`: the dark horizontal logo at 392x70, at the bottom
- the spinner: Fedora's frames tinted with the orbit blues at build time
  (`build_files/plymouth/tint.py`)

The theme file itself is generated from Fedora's `bgrt.plymouth` during the
build (`build_files/20-cosmic.sh`), so it follows Fedora's settings.

Regenerate the SVGs with `python3 logo/build.py`.

## Wallpaper

Two versions of the same scene, 5120x2880, in
`system_files/usr/share/backgrounds/cosmic-blue/`:

- `cosmic-blue.jpg`: night sky, the default COSMIC wallpaper
- `cosmic-blue-light.jpg`: pale sky, for the light theme

Keep the main elements inside the centre so they survive cropping to 16:10,
4:3 and 21:9.

COSMIC 1.11 has one wallpaper for both themes (`com.system76.CosmicBackground`),
so the light one is offered in Settings. Later COSMIC releases read a wallpaper
per theme (`com.system76.CosmicBackground.Dark` / `.Light`); those defaults are
already set, so the wallpaper will follow the theme once Fedora ships them.

Each wallpaper is built from two layers:

- `wallpaper/sky.py`: sky gradient, procedural Milky Way and stars (numpy);
  writes the night sky and the pale sky from the same Milky Way
- `wallpaper/foreground.py dark|light`: the logo as a scene, a planet inside a
  glowing open orbit with a moon in the gap (SVG, rendered by
  `wallpaper/render.js` with Playwright's Chromium)

`wallpaper/build.sh` renders both versions; `wallpaper/compose.py` dims the
sky behind the planet (dark) or lightens it (light), adds a fine grain against
banding and writes the JPEG. The output is deterministic (fixed seeds).
