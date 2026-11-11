#!/usr/bin/python3
"""Patches the COSMIC first-run assistant (cosmic-initial-setup) for cosmic-blue.

1. Appearance page: the "COSMIC Dark" and "COSMIC Light" choices use the
   theme builders found in the COSMIC config (our defaults from
   /usr/share/cosmic: blue accent, frosted glass) instead of the built-in
   upstream themes (teal). Clicking a theme or the frosted glass switch no
   longer writes the upstream teal theme to the new account. The frosted
   glass switch starts from the current theme instead of "off".
2. Accessibility: the screen reader is no longer turned on when the
   assistant starts. It can still be turned on from the accessibility page.

Each replacement must match exactly once, so the build fails loudly when a
new upstream version changes this code. Usage: patch.py <source dir>
"""

import pathlib
import sys

src = pathlib.Path(sys.argv[1])


def replace(rel, old, new):
    path = src / rel
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        sys.exit(f"{rel}: expected 1 match, found {count}:\n{old}")
    path.write_text(text.replace(old, new))


def configured(kind):
    return (
        f"match ThemeBuilder::{kind}_config() {{\n"
        f"                    Ok(config) => match ThemeBuilder::get_entry(&config) {{\n"
        f"                        Ok(builder) => builder,\n"
        f"                        Err((_, builder)) => builder,\n"
        f"                    }},\n"
        f"                    Err(_) => ThemeBuilder::{kind}(),\n"
        f"                }},"
    )


appearance = "src/page/appearance.rs"
replace(appearance, "builder: ThemeBuilder::dark(),", "builder: " + configured("dark"))
replace(appearance, "builder: ThemeBuilder::light(),", "builder: " + configured("light"))
replace(
    appearance,
    "        Self {\n            theme_mode_config,",
    "        let frosted_glass = themes\n"
    "            .get(if ThemeMode::default().is_dark { 0 } else { 1 })\n"
    "            .is_some_and(|theme| theme.builder.frosted_windows);\n\n"
    "        Self {\n            theme_mode_config,",
)
replace(appearance, "            frosted_glass: false,\n", "            frosted_glass,\n")

replace(
    "src/page/a11y.rs",
    "                    self.screen_reader_dbus_sender = Some(tx);\n"
    "                    return cosmic::Task::done(Message::ScreenReaderEnabled(true).into());\n",
    "                    self.screen_reader_dbus_sender = Some(tx);\n",
)

print("cosmic-initial-setup patched")
