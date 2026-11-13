//! Writes the cosmic-blue default COSMIC themes (dark and light) with the
//! frosted glass effect turned on, to $XDG_CONFIG_HOME/cosmic.
//!
//! COSMIC apps read the computed theme (com.system76.CosmicTheme.*), not the
//! builder that COSMIC Settings edits, and the frosted glass switches change
//! the computed colors (transparency). So both are generated with the same
//! code as COSMIC Settings, and shipped as system defaults in /usr/share/cosmic.
//!
//! The colors revolve around the "cosmic" blue of the logo and wallpaper:
//! - the accent is a blue from the logo instead of COSMIC's default teal;
//! - the window background is a deep night blue instead of neutral gray, and
//!   the controls get a slight tint of the same hue (COSMIC derives every
//!   surface from these, keeping hue and chroma, so they stay discreet).
//!
//! The window hint (the outline of the active window) is left unset, so it
//! follows the accent, also when the user picks another accent in COSMIC
//! Settings. Every color can still be changed there (Appearance).

use cosmic_config::CosmicConfigEntry;
use cosmic_theme::palette::{Srgb, Srgba};
use cosmic_theme::{Theme, ThemeBuilder};

/// Dark theme accent: the middle of the logo orbit gradient (#4f8dff).
const ACCENT_DARK: Srgb<u8> = Srgb::new(0x4f, 0x8d, 0xff);
/// Light theme accent: the deep blue of the logo planet (#1d47c4), dark
/// enough to stay readable on light surfaces.
const ACCENT_LIGHT: Srgb<u8> = Srgb::new(0x1d, 0x47, 0xc4);

/// Window background, dark theme: night blue at the lightness of COSMIC's
/// default dark gray (oklch 0.225 0.03, hue of the accent).
const BG_DARK: Srgb<u8> = Srgb::new(0x14, 0x1c, 0x2a);
/// Window background, light theme: a cool, barely blue gray at the lightness
/// of COSMIC's default light gray (oklch 0.88 0.012).
const BG_LIGHT: Srgb<u8> = Srgb::new(0xd3, 0xd8, 0xe0);
/// Tint of buttons and other controls (oklch chroma 0.03, hue of the accent;
/// COSMIC only keeps its hue and chroma).
const NEUTRAL_TINT: Srgb<u8> = Srgb::new(0x5a, 0x64, 0x75);

fn colors(builder: ThemeBuilder, accent: Srgb<u8>, bg: Srgb<u8>) -> ThemeBuilder {
    let bg: Srgb = bg.into_format();
    builder
        .accent(accent.into_format())
        .bg_color(Srgba::new(bg.red, bg.green, bg.blue, 1.0))
        .neutral_tint(NEUTRAL_TINT.into_format())
}

/// The same switches as "Frosted glass" in COSMIC's first-run assistant.
fn frosted(mut builder: ThemeBuilder) -> ThemeBuilder {
    builder.frosted_windows = true;
    builder.frosted_system_interface = true;
    builder.frosted_panel = true;
    builder.frosted_applets = true;
    builder
}

/// Writes a dark and a light theme (builder and computed theme).
fn write(dark: ThemeBuilder, light: ThemeBuilder) {
    dark.write_entry(&ThemeBuilder::dark_config().expect("dark builder config"))
        .expect("write dark builder");
    dark.build()
        .write_entry(&Theme::dark_config().expect("dark theme config"))
        .expect("write dark theme");

    light
        .write_entry(&ThemeBuilder::light_config().expect("light builder config"))
        .expect("write light builder");
    light
        .build()
        .write_entry(&Theme::light_config().expect("light theme config"))
        .expect("write light theme");
}

/// Without an argument: the cosmic-blue themes. With "stock" or "frosted":
/// themes from earlier images, which accounts may still hold as a copy
/// (COSMIC's own default, written by the first-run assistant, and the same
/// with frosted glass, the default before the blue colors). They go into
/// /usr/share/cosmic-blue/previous-defaults.list, so that
/// cosmic-blue-migrate-defaults can tell them from a user's own choice.
fn main() {
    match std::env::args().nth(1).as_deref() {
        None => write(
            colors(frosted(ThemeBuilder::dark()), ACCENT_DARK, BG_DARK),
            colors(frosted(ThemeBuilder::light()), ACCENT_LIGHT, BG_LIGHT),
        ),
        Some("stock") => write(ThemeBuilder::dark(), ThemeBuilder::light()),
        Some("frosted") => write(frosted(ThemeBuilder::dark()), frosted(ThemeBuilder::light())),
        Some(other) => panic!("unknown theme variant {other}"),
    }
}
