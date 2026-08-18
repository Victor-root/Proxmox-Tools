/* ============================================================================
 * THE ONLY FILE YOU NEED TO EDIT TO ADD OR CHANGE A SCRIPT.
 *
 * To add a script:
 *   1. push the script into scripts/ on the main branch
 *   2. copy one block of SCRIPTS below, paste it, change the values
 *   3. commit: the site rebuilds itself and the card appears
 *
 * Fields of a script block
 *   id        anchor used in the URL, lowercase, no spaces
 *   file      exact file name inside scripts/, the run command is built from it
 *   name      short title shown on the card
 *   tagline   one line, what it does, shown under the title
 *   runsOn    where the user must run it
 *   compat    supported versions, shown as a small badge
 *   updated   free text, shown in the "What's new" list, keep it short
 *   points    3 to 5 short bullets, no long sentences
 *   terminal  what the fake terminal shows, see below
 *
 * terminal.banner   "proxmox" or "wireguard", the ASCII logo to draw
 * terminal.theme    "orange" (Proxmox scripts) or "red" (WireGuard script)
 * terminal.subtitle line printed under the logo
 * terminal.panel    optional box: { title, lines: [] }
 * terminal.menu     the menu entries, in order
 * terminal.prompt   the question printed at the bottom
 * ==========================================================================*/

const SITE = {
    repo: 'Victor-root/Proxmox-Tools',
    branch: 'main',
    scriptsDir: 'scripts',
};

const SCRIPTS = [
    {
        id: 'console-newtab',
        file: 'pve-console-newtab.sh',
        name: 'Console in a new tab',
        tagline: 'Middle click a console button, it opens in a browser tab instead of a popup window.',
        runsOn: 'Proxmox VE host, as root',
        compat: 'PVE 8.4.2 to 9.2',
        updated: 'Each patched file is now checked on its own, so a partial Proxmox update can simply be re-patched.',
        points: [
            'Middle click on Console, noVNC or xterm.js opens a real browser tab',
            'Middle click on SPICE behaves like a normal click, no useless empty tab',
            'Automatic backup before patching, restore from the menu',
            'Stops and touches nothing if your Proxmox version is not supported',
        ],
        terminal: {
            banner: 'proxmox',
            theme: 'orange',
            subtitle: 'Console New Tab Patch Utility',
            panel: {
                title: 'Interactive patch utility for the Proxmox VE web interface',
                lines: ['Host: pve01', 'Detected language: English'],
            },
            menu: [
                'Apply patch (automatic backup included)',
                'Restore latest backup',
                'Restore from selected backup',
                'Show patch status',
                'List backups',
                'Quit',
            ],
            prompt: 'Choose an option [1-6]:',
        },
    },
    {
        id: 'subscription-notice',
        file: 'pve-remove-subscription-notice.sh',
        name: 'Remove the subscription notice',
        tagline: 'Drops the "No valid subscription" popup, without breaking the buttons behind it.',
        runsOn: 'Proxmox VE host, as root',
        compat: 'PVE 8.0 to 9.2',
        updated: 'New script. Optional APT hook re-applies the patch after a package update.',
        points: [
            'No more popup at every login',
            'Package versions, system report, APT refresh and add repository keep working',
            'Optional automatic re-apply after a package update',
            'Automatic backup before patching, restore from the menu',
        ],
        note: 'Proxmox VE stays free software either way. A subscription funds its development and unlocks the enterprise repository.',
        terminal: {
            banner: 'proxmox',
            theme: 'orange',
            subtitle: 'Subscription Notice Remover',
            panel: {
                title: 'Patch status',
                lines: [
                    'Detected version: proxmox-widget-toolkit 5.2.8',
                    'Subscription notice: removed',
                    'Automatic re-apply: enabled',
                ],
            },
            menu: [
                'Apply patch (automatic backup included)',
                'Restore latest backup',
                'Restore from selected backup',
                'Show patch status',
                'List backups',
                'Re-apply automatically after an update',
                'Stop re-applying automatically',
                'Quit',
            ],
            prompt: 'Choose an option [1-8]:',
        },
    },
    {
        id: 'default-language',
        file: 'pve-default-language-i18n',
        name: 'Default language manager',
        tagline: 'Sets the language of the shell and of the Proxmox web interface, in one place.',
        runsOn: 'Proxmox VE host, as root',
        compat: 'PVE 8.x and 9.x',
        updated: 'Croatian, Georgian and Ukrainian added. 29 languages available.',
        points: [
            'Sets the system locale and the web interface language together',
            '29 languages, the script interface speaks them too',
            'Optional timezone and NTP setup',
            'Warns instead of writing a language Proxmox would silently drop',
        ],
        terminal: {
            banner: 'proxmox',
            theme: 'orange',
            subtitle: 'Default Language Utility',
            panel: {
                title: 'Summary',
                lines: [
                    'PVE web UI language: fr',
                    'System locale: fr_FR.UTF-8',
                    'Timezone: Europe/Paris',
                ],
            },
            menu: [
                'Apply default language',
                'Restore latest backup',
                'Restore from selected backup',
                'Show current status',
                'List supported languages',
                'List backups',
                'Quit',
            ],
            prompt: 'Choose an option [1-7]:',
        },
    },
    {
        id: 'wireguard',
        file: 'lxc-wireguard-server-install.sh',
        name: 'WireGuard VPN server',
        tagline: 'Installs and manages a WireGuard server inside an LXC, clients and QR codes included.',
        runsOn: 'Inside a Debian or Ubuntu LXC, as root',
        compat: 'Debian / Ubuntu LXC',
        updated: 'Client list now follows the order of wg0.conf, and the config is remembered after the first run.',
        points: [
            'Guided install with three clear network modes',
            'Add, list, show and revoke clients, QR code included',
            'Diagnostic that checks the service, the port, routing and the firewall',
            'Built-in backup and restore, and a clean uninstall',
        ],
        note: 'Run it inside the container, not on the Proxmox host. On an unprivileged LXC the script tells you the exact pct commands to run first.',
        terminal: {
            banner: 'wireguard',
            theme: 'red',
            subtitle: 'Installation, configuration et gestion du serveur WireGuard',
            panel: {
                title: 'Les trois modes',
                lines: [
                    '1) Privé : seuls les appareils WireGuard communiquent entre eux.',
                    '2) LAN : les clients peuvent accéder au réseau local derrière le serveur.',
                    '3) Full tunnel : Internet des clients passe par le serveur.',
                ],
            },
            menu: [
                'Installer ou reconfigurer le serveur WireGuard',
                'Ajouter ou régénérer un client',
                'Lister les clients et leur état',
                'Afficher / re-scanner un client (config + QR)',
                'Supprimer un client',
                'Diagnostic (vérifier que tout marche)',
                'Aide redirection de port',
                'Sauvegarde / restauration de la configuration',
                'Désinstaller le serveur WireGuard',
                'Quitter',
            ],
            prompt: 'Votre choix [1]:',
        },
    },
];

/* ASCII logos drawn at the top of each script. Add one here only if a new
 * script ships a new logo, then point terminal.banner at its key. */
const BANNERS = {
    proxmox: [
        '██████╗ ██████╗  ██████╗ ██╗  ██╗███╗   ███╗ ██████╗ ██╗  ██╗',
        '██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝████╗ ████║██╔═══██╗╚██╗██╔╝',
        '██████╔╝██████╔╝██║   ██║ ╚███╔╝ ██╔████╔██║██║   ██║ ╚███╔╝ ',
        '██╔═══╝ ██╔══██╗██║   ██║ ██╔██╗ ██║╚██╔╝██║██║   ██║ ██╔██╗ ',
        '██║     ██║  ██║╚██████╔╝██╔╝ ██╗██║ ╚═╝ ██║╚██████╔╝██╔╝ ██╗',
        '╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝',
    ],
    wireguard: [
        '██╗    ██╗██╗██████╗ ███████╗ ██████╗ ██╗   ██╗ █████╗ ██████╗ ██████╗',
        '██║    ██║██║██╔══██╗██╔════╝██╔════╝ ██║   ██║██╔══██╗██╔══██╗██╔══██╗',
        '██║ █╗ ██║██║██████╔╝█████╗  ██║  ███╗██║   ██║███████║██████╔╝██║  ██║',
        '██║███╗██║██║██╔══██╗██╔══╝  ██║   ██║██║   ██║██╔══██║██╔══██╗██║  ██║',
        '╚███╔███╔╝██║██║  ██║███████╗╚██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝',
        ' ╚══╝╚══╝ ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝',
    ],
};
