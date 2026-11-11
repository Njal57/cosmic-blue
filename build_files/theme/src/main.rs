//! Writes the cosmic-blue default COSMIC themes (dark and light) with the
//! frosted glass effect turned on, to $XDG_CONFIG_HOME/cosmic.
//!
//! COSMIC apps read the computed theme (com.system76.CosmicTheme.*), not the
//! builder that COSMIC Settings edits, and the frosted glass switches change
//! the computed colors (transparency). So both are generated with the same
//! code as COSMIC Settings, and shipped as system defaults in /usr/share/cosmic.
//!
//! The accent color is a blue from the cosmic-blue logo instead of COSMIC's
//! default teal. The window hint (the outline of the active window) is left
//! unset, so it follows the accent, also when the user picks another accent
//! in COSMIC Settings.

use cosmic_config::CosmicConfigEntry;
use cosmic_theme::palette::Srgb;
use cosmic_theme::{Theme, ThemeBuilder};

/// Dark theme accent: the middle of the logo orbit gradient (#4f8dff).
const ACCENT_DARK: Srgb<u8> = Srgb::new(0x4f, 0x8d, 0xff);
/// Light theme accent: the deep blue of the logo planet (#1d47c4), dark
/// enough to stay readable on light surfaces.
const ACCENT_LIGHT: Srgb<u8> = Srgb::new(0x1d, 0x47, 0xc4);

/// The same switches as "Frosted glass" in COSMIC's first-run assistant.
fn frosted(mut builder: ThemeBuilder) -> ThemeBuilder {
    builder.frosted_windows = true;
    builder.frosted_system_interface = true;
    builder.frosted_panel = true;
    builder.frosted_applets = true;
    builder
}

fn main() {
    let dark = frosted(ThemeBuilder::dark()).accent(ACCENT_DARK.into_format());
    dark.write_entry(&ThemeBuilder::dark_config().expect("dark builder config"))
        .expect("write dark builder");
    dark.build()
        .write_entry(&Theme::dark_config().expect("dark theme config"))
        .expect("write dark theme");

    let light = frosted(ThemeBuilder::light()).accent(ACCENT_LIGHT.into_format());
    light
        .write_entry(&ThemeBuilder::light_config().expect("light builder config"))
        .expect("write light builder");
    light
        .build()
        .write_entry(&Theme::light_config().expect("light theme config"))
        .expect("write light theme");
}
