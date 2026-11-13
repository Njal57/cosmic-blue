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

All 5120x2880, in `system_files/usr/share/backgrounds/cosmic-blue/`:

- `cosmic-blue-orbits.jpg`: a planetary system seen from above its plane (a
  bright star, shaded planets, a ringed giant, an asteroid belt) over the
  Milky Way, the default COSMIC wallpaper
- `cosmic-blue.jpg`: the logo as a scene, offered in Settings
- `cosmic-blue-waves.jpg`: layered ribbons of light, offered in Settings
- `cosmic-blue-milky-way.jpg`: the Milky Way above the Earth, a photo taken
  on the International Space Station (NASA, ISS064-E-55946, public domain),
  graded with the cosmic-blue palette, offered in Settings

Keep the main elements inside the centre so they survive cropping to 16:10,
4:3 and 21:9. `wallpaper/build.sh` renders them all (the NASA original is
downloaded); the output is deterministic (fixed seeds). Keep the file names:
accounts that picked a wallpaper in Settings point to its path.

There are no light versions: the same wallpaper serves both themes. Later
COSMIC releases read a wallpaper per theme (`com.system76.CosmicBackground.Dark`
/ `.Light`); both point to the default.

`wallpaper/orbits.py` draws the planetary system with numpy over
the sky of `wallpaper/sky.py`. The waves are drawn as SVG by
`wallpaper/concept.py`, rendered by `wallpaper/render.js` and finished by
`wallpaper/compose.py concept` (a fine grain against banding). `wallpaper/milky_way.py` crops and grades the photo.

The logo scene is built from two layers:

- `wallpaper/sky.py`: sky gradient, procedural Milky Way and stars (numpy),
  also the background of the orbits
- `wallpaper/foreground.py`: the logo as a scene, a planet inside a
  glowing open orbit with a moon in the gap (SVG, rendered by
  `wallpaper/render.js` with Playwright's Chromium)

`wallpaper/compose.py dark` dims the
sky, adds a blue glow behind the planet and a fine grain against banding, and
writes the JPEG.

## fastfetch

`fastfetch` or `ff` (aliases of `ublue-fastfetch`) shows the mark as terminal art
next to the system information, in place of Bluefin's dinosaurs:

- `system_files/usr/share/ublue-os/fastfetch/cosmic-blue-dark.txt` /
  `-light.txt`: the mark as 40x40 color pixels, two per terminal cell (the
  upper half block on a background color), with edges blended into the
  theme's terminal background. COSMIC Terminal draws glyphs shorter than the
  cell, so stacked block glyphs leave lines between rows; cell backgrounds
  don't, and the upper half block never has to reach the cell bottom. The
  light version darkens the moon and the planet highlight. Regenerate them
  with `python3 fastfetch/build.py` (needs `rsvg-convert`, numpy and
  Pillow); it picks the size and position of the logo that give the
  cleanest curves.
- `system_files/usr/share/ublue-os/fastfetch.jsonc`: the modules (image, OS,
  COSMIC version, hardware...), with Nerd Font icons
- `system_files/usr/bin/ublue-fastfetch`: picks the logo for the COSMIC
  dark/light mode; `ublue-bling-fastfetch` gives the keys the COSMIC accent
  color. A user's own `~/.config/fastfetch/config.jsonc` is used instead
  when it exists.

## Shell prompt font

`system_files/usr/share/fonts/cosmic-blue/cosmic-blue-prompt.ttf`, generated
by `python3 prompt-font/build.py <output>` (fontTools): the arrows, the logo
mark and the icons of the Starship prompt
(`system_files/usr/share/cosmic-blue/starship.toml`), in plane 16 private use
code points. The arrows span COSMIC Terminal's whole line (1.4 times the font
size, with its default font Noto Sans Mono); Nerd Font arrows only reach the
font's own height there.

## Icons

The `cosmic-blue` icon theme is Tela circle, recolored with the accent
(`build_files/icon_theme/`), with a few icons of our own in front of it.
`icons/build.py` draws them as SVG:

- folders, home, desktop, network and trash (`build_files/icon_theme/layer/places/`):
  a disk in the logo blues with a folder tab and a white symbol, inside the
  logo's orbit
- common file types (`build_files/icon_theme/layer/mimetypes/`): a light page
  whose symbol and folded corner take the color of the type (documents blue,
  spreadsheets green, archives amber...). Language-specific icons (Python,
  Rust...) stay Tela's.
- the live ISO's welcome tour and installer (`iso_files/welcome/*.svg`): the
  mark on a night-blue disk

The files are named like Tela's, and the theme also takes every name that
Tela links to them (`build_files/icon_theme/compose.py`). Regenerate them with
`python3 icons/build.py` after a change.
