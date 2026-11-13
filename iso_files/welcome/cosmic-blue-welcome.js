#!/usr/bin/gjs -m
// cosmic-blue welcome tour, shown when the live session starts.
// A few pages that present cosmic-blue, then offer to start the installer.
// GTK 4 + libadwaita, in the style of Fedora's live welcome screen
// (anaconda: data/liveinst/gnome/fedora-welcome.js).
//
// Text is in English, with a French translation picked from the session
// language. To add a language, add an entry to TRANSLATIONS.

import Adw from 'gi://Adw?version=1';
import Gdk from 'gi://Gdk?version=4.0';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Gtk from 'gi://Gtk?version=4.0';

import {programArgs, programInvocationName} from 'system';

const APP_ID = 'io.github.cosmic_blue_os.Welcome';
const INSTALLER_DESKTOP_IDS = ['liveinst.desktop', 'anaconda.desktop'];

const TRANSLATIONS = {
    fr: {
        'Welcome': 'Bienvenue',
        'Welcome to cosmic-blue':
            'Bienvenue dans cosmic-blue',
        'cosmic-blue is Fedora Atomic with the COSMIC desktop, made in the spirit of Bluefin: a desktop that stays out of your way and keeps itself up to date.':
            'cosmic-blue, c’est Fedora Atomic avec le bureau COSMIC, dans l’esprit de Bluefin : un bureau qui se fait oublier et se tient à jour tout seul.',
        'Try it live':
            'Essayez-le en live',
        'cosmic-blue is running from the live media. Nothing is written to your disk, and your changes are lost when you shut down.':
            'cosmic-blue fonctionne depuis le support live. Rien n’est écrit sur votre disque, et vos modifications sont perdues à l’extinction.',
        'You can start the installer at any time from the desktop or the dock.':
            'Vous pouvez lancer l’installateur à tout moment depuis le bureau ou le dock.',
        'What you get':
            'Ce qui vous attend',
        'Automatic updates':
            'Mises à jour automatiques',
        'The whole system updates in the background and applies at the next restart. If something goes wrong, boot the previous version.':
            'Le système entier se met à jour en arrière-plan et s’applique au redémarrage suivant. En cas de souci, démarrez la version précédente.',
        'Apps from Flathub and COSMIC':
            'Applications de Flathub et COSMIC',
        'Install apps with COSMIC Store, from Flathub and the COSMIC repository. They run sandboxed and update on their own.':
            'Installez vos applications avec COSMIC Store, depuis Flathub et le dépôt COSMIC. Elles tournent isolées et se mettent à jour seules.',
        'Ready for the terminal':
            'Prêt pour le terminal',
        'Homebrew for command line tools, distrobox for other distributions, and ujust for common tasks.':
            'Homebrew pour les outils en ligne de commande, distrobox pour les autres distributions, et ujust pour les tâches courantes.',
        'Ready to install?':
            'Prêt à installer ?',
        'The installer copies cosmic-blue to your disk. After that, it updates itself from the cosmic-blue image registry.':
            'L’installateur copie cosmic-blue sur votre disque. Ensuite, il se met à jour depuis le registre d’images de cosmic-blue.',
        'Install cosmic-blue':
            'Installer cosmic-blue',
        'Keep trying':
            'Continuer l’essai',
        'Back':
            'Précédent',
        'Next':
            'Suivant',
    },
};

const strings = (() => {
    for (const name of GLib.get_language_names()) {
        const lang = name.split(/[_.@]/)[0];
        if (lang in TRANSLATIONS)
            return TRANSLATIONS[lang];
        if (lang === 'en' || lang === 'C')
            break;
    }
    return {};
})();

function _(text) {
    return strings[text] ?? text;
}

function findInstaller() {
    for (const id of INSTALLER_DESKTOP_IDS) {
        const app = Gio.DesktopAppInfo.new(id);
        if (app)
            return app;
    }
    return null;
}

// First icon name of `names` that the icon theme has.
function pickIcon(...names) {
    const theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default());
    return names.find(name => theme.has_icon(name)) ?? names[names.length - 1];
}

function statusPage(iconName, title, description, child = null) {
    const page = new Adw.StatusPage({
        icon_name: iconName,
        title,
        description,
        hexpand: true,
        vexpand: true,
    });
    if (child)
        page.set_child(child);
    return page;
}

function featureList() {
    const group = new Adw.PreferencesGroup({
        margin_start: 12,
        margin_end: 12,
    });
    const features = [
        ['software-update-available-symbolic', 'Automatic updates',
            'The whole system updates in the background and applies at the next restart. If something goes wrong, boot the previous version.'],
        ['system-software-install-symbolic', 'Apps from Flathub and COSMIC',
            'Install apps with COSMIC Store, from Flathub and the COSMIC repository. They run sandboxed and update on their own.'],
        ['utilities-terminal-symbolic', 'Ready for the terminal',
            'Homebrew for command line tools, distrobox for other distributions, and ujust for common tasks.'],
    ];
    for (const [icon, title, subtitle] of features) {
        const row = new Adw.ActionRow({title: _(title), subtitle: _(subtitle)});
        row.add_prefix(new Gtk.Image({icon_name: icon, pixel_size: 24}));
        group.add(row);
    }
    return new Adw.Clamp({maximum_size: 520, child: group});
}

class WelcomeWindow extends Adw.ApplicationWindow {
    static {
        GObject.registerClass(this);
    }

    constructor(application) {
        super({
            application,
            title: _('Welcome'),
            default_width: 720,
            default_height: 620,
        });

        this._installer = findInstaller();

        const closeAction = new Gio.SimpleAction({name: 'keep-trying'});
        closeAction.connect('activate', () => this.close());
        this.add_action(closeAction);
        const installAction = new Gio.SimpleAction({name: 'install'});
        installAction.connect('activate', () => this._install());
        installAction.enabled = this._installer !== null;
        this.add_action(installAction);

        this._carousel = new Adw.Carousel({
            hexpand: true,
            vexpand: true,
            allow_scroll_wheel: true,
        });

        this._carousel.append(statusPage(pickIcon('cosmic-blue-logo', 'fedora-logo-icon', 'computer-symbolic'),
            _('Welcome to cosmic-blue'),
            _('cosmic-blue is Fedora Atomic with the COSMIC desktop, made in the spirit of Bluefin: a desktop that stays out of your way and keeps itself up to date.')));
        this._carousel.append(statusPage('media-optical-symbolic',
            _('Try it live'),
            `${_('cosmic-blue is running from the live media. Nothing is written to your disk, and your changes are lost when you shut down.')}\n\n${
                _('You can start the installer at any time from the desktop or the dock.')}`));
        this._carousel.append(statusPage('starred-symbolic',
            _('What you get'), null, featureList()));
        this._carousel.append(statusPage('drive-harddisk-symbolic',
            _('Ready to install?'),
            _('The installer copies cosmic-blue to your disk. After that, it updates itself from the cosmic-blue image registry.'),
            this._finalButtons()));

        this._back = new Gtk.Button({label: _('Back'), valign: Gtk.Align.CENTER});
        this._back.connect('clicked', () => this._scrollBy(-1));
        this._next = new Gtk.Button({label: _('Next'), valign: Gtk.Align.CENTER});
        this._next.add_css_class('suggested-action');
        this._next.connect('clicked', () => this._scrollBy(1));
        this._carousel.connect('page-changed', () => this._updateButtons());

        const bottom = new Gtk.CenterBox({
            margin_start: 18,
            margin_end: 18,
            margin_top: 6,
            margin_bottom: 18,
            start_widget: this._back,
            center_widget: new Adw.CarouselIndicatorDots({carousel: this._carousel}),
            end_widget: this._next,
        });

        const content = new Gtk.Box({orientation: Gtk.Orientation.VERTICAL});
        content.append(this._carousel);
        content.append(bottom);

        const toolbar = new Adw.ToolbarView({content});
        toolbar.add_top_bar(new Adw.HeaderBar({show_title: false}));
        this.set_content(toolbar);

        const escape = new Gtk.ShortcutController();
        escape.add_shortcut(new Gtk.Shortcut({
            trigger: Gtk.ShortcutTrigger.parse_string('Escape'),
            action: Gtk.NamedAction.new('window.close'),
        }));
        this.add_controller(escape);

        this._updateButtons();
    }

    _finalButtons() {
        const box = new Gtk.Box({
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 12,
            halign: Gtk.Align.CENTER,
        });
        const install = new Gtk.Button({
            label: _('Install cosmic-blue'),
            action_name: 'win.install',
        });
        install.add_css_class('pill');
        install.add_css_class('suggested-action');
        box.append(install);
        const keepTrying = new Gtk.Button({
            label: _('Keep trying'),
            action_name: 'win.keep-trying',
        });
        keepTrying.add_css_class('pill');
        box.append(keepTrying);
        return box;
    }

    _scrollBy(delta) {
        const target = Math.round(this._carousel.position) + delta;
        if (target < 0 || target >= this._carousel.n_pages)
            return;
        this._carousel.scroll_to(this._carousel.get_nth_page(target), true);
    }

    _updateButtons() {
        const position = Math.round(this._carousel.position);
        this._back.opacity = position > 0 ? 1 : 0;
        this._back.sensitive = position > 0;
        const last = position >= this._carousel.n_pages - 1;
        this._next.opacity = last ? 0 : 1;
        this._next.sensitive = !last;
    }

    _install() {
        try {
            this._installer.launch([], this.get_display().get_app_launch_context());
        } catch (e) {
            logError(e, 'Could not start the installer');
            return;
        }
        this.close();
    }
}

class WelcomeApp extends Adw.Application {
    static {
        GObject.registerClass(this);
    }

    constructor() {
        super({application_id: APP_ID});
    }

    vfunc_activate() {
        let window = this.active_window;
        if (!window)
            window = new WelcomeWindow(this);
        window.present();
    }
}

new WelcomeApp().run([programInvocationName, ...programArgs]);
