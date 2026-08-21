/* ============================================================================
 * THE ONLY FILE YOU NEED TO EDIT TO ADD OR CHANGE A SCRIPT.
 *
 * Every text is bilingual: { en: 'English', fr: 'Français' }.
 * If a translation is missing the English one is used.
 *
 * To add a script:
 *   1. push the script into scripts/ on the main branch
 *   2. copy one block of SCRIPTS below, paste it, change the values
 *   3. commit: the site rebuilds itself and the card appears
 *
 * Fields of a script block
 *   id        anchor used in the URL, lowercase, no spaces
 *   icon      Tabler icon key, see the sprite in index.html (browser, bell-off, …)
 *   file      exact file name inside scripts/, the run command is built from it
 *   target    "pve" (Proxmox host) or "lxc" (inside a container), picks the icon
 *   name      short title shown on the card
 *   tagline   one line, what it does
 *   runsOn    where the user must run it
 *   compat    supported versions, small badge, same text in both languages
 *   updated   what changed, one short line, shown in "What's new"
 *   points    3 to 5 short bullets
 *   touches   what the script writes on the machine, see below
 *   note      optional warning, shown in a quieter box
 *   terminal  what the fake terminal shows, see below
 *
 * touches.files    [{ path, role }], every file the script writes or creates
 * touches.installs optional, the packages it adds
 * touches.backup   where the copy it keeps before changing anything goes
 * touches.restarts the services it restarts
 *
 * terminal.banner   "proxmox" or "wireguard", the ASCII logo to draw
 * terminal.theme    "orange" (Proxmox scripts) or "red" (WireGuard script)
 * terminal.host     machine name in the window title and in the shell prompt
 * terminal.subtitle line printed under the logo, as printed by the script
 * terminal.panel    optional box: { title, lines: [] }
 * terminal.menu     the menu entries, in order
 * terminal.prompt   the question printed at the bottom
 *
 * The terminal shows the script exactly as it runs, so its text is NOT
 * translated: every script speaks the locale of the server, English by default,
 * and that default is what the preview shows.
 * The first script of the list is also the one shown in the hero terminal.
 * ==========================================================================*/

const SITE = {
    repo: 'Victor-root/Proxmox-Tools',
    branch: 'main',
    scriptsDir: 'scripts',
    author: 'Victor-root',
};

const SCRIPTS = [
    {
        id: 'default-language',
        icon: 'language',
        file: 'pve-default-language-i18n',
        target: 'pve',
        name: {
            en: 'Default language manager',
            fr: 'Gestionnaire de langue par défaut',
        },
        tagline: {
            en: 'Sets the language of the shell and of the Proxmox web interface, in one place.',
            fr: 'Règle la langue du shell et celle de l’interface web Proxmox, au même endroit.',
        },
        runsOn: {
            en: 'Proxmox VE host, as root',
            fr: 'Sur l’hôte Proxmox VE, en root',
        },
        compat: 'PVE 8.x / 9.x',
        updated: {
            en: 'Croatian, Georgian and Ukrainian added. 29 languages available.',
            fr: 'Ajout du croate, du géorgien et de l’ukrainien. 29 langues disponibles.',
        },
        points: {
            en: [
                'Sets the system locale and the web interface language together',
                '29 languages, the script interface speaks them too',
                'Optional timezone and NTP setup',
                'Warns instead of writing a language Proxmox would silently drop',
            ],
            fr: [
                'Règle la locale système et la langue de l’interface web ensemble',
                '29 langues, l’interface du script les parle aussi',
                'Configuration optionnelle du fuseau horaire et du NTP',
                'Prévient au lieu d’écrire une langue que Proxmox ignorerait',
            ],
        },
        touches: {
            files: [
                { path: '/etc/pve/datacenter.cfg', role: { en: 'web interface language', fr: 'langue de l’interface web' } },
                { path: '/etc/default/locale', role: { en: 'system locale', fr: 'locale du système' } },
                { path: '/etc/locale.gen', role: { en: 'locales to generate', fr: 'locales à générer' } },
                { path: '/etc/profile.d/proxmox-tools-locale.sh', role: { en: 'created, applies the locale to each shell', fr: 'créé, applique la locale à chaque shell' } },
                { path: '/etc/timezone', role: { en: 'only if you choose a timezone', fr: 'seulement si vous choisissez un fuseau horaire' } },
            ],
            backup: '/root/pve-default-language-<date>/',
            restarts: 'pveproxy',
        },
        terminal: {
            banner: 'proxmox',
            theme: 'orange',
            host: 'root@pve01',
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
        id: 'subscription-notice',
        icon: 'bell-off',
        file: 'pve-remove-subscription-notice.sh',
        target: 'pve',
        name: {
            en: 'Remove the subscription notice',
            fr: 'Supprimer le popup d’abonnement',
        },
        tagline: {
            en: 'Drops the "No valid subscription" popup, without breaking the buttons behind it.',
            fr: 'Enlève le popup « No valid subscription » sans casser les boutons qui en dépendent.',
        },
        runsOn: {
            en: 'Proxmox VE host, as root',
            fr: 'Sur l’hôte Proxmox VE, en root',
        },
        compat: 'PVE 8.0 → 9.2',
        updated: {
            en: 'Separate option for the mobile interface, which is another application and keeps its own popup.',
            fr: 'Option séparée pour l’interface mobile, une autre application qui garde son propre popup.',
        },
        points: {
            en: [
                'No more popup at every login',
                'Package versions, system report, APT refresh and add repository keep working',
                'Separate option for the mobile interface, patched on its own with its own way back',
                'Optional automatic re-apply after a package update',
                'Automatic backup before patching, restore from the menu',
            ],
            fr: [
                'Plus de popup à chaque connexion',
                'Versions des paquets, rapport système, actualisation APT et ajout de dépôt continuent de fonctionner',
                'Option séparée pour l’interface mobile, patchée à part avec son propre retour arrière',
                'Réapplication automatique optionnelle après une mise à jour',
                'Backup automatique avant le patch, restauration depuis le menu',
            ],
        },
        touches: {
            files: [
                { path: '/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js', role: { en: 'one line changed, the one that shows the popup', fr: 'une ligne modifiée, celle qui affiche le popup' } },
                { path: '/usr/share/perl5/PVE/API2Tools.pm', role: { en: 'one line changed, only if you patch the mobile interface too', fr: 'une ligne modifiée, seulement si vous patchez aussi l’interface mobile' } },
                { path: '/etc/apt/apt.conf.d/99-pve-remove-subscription-notice', role: { en: 'created only if you turn on the automatic re-apply', fr: 'créé seulement si vous activez la réapplication automatique' } },
            ],
            backup: '/root/pve-subscription-notice-patch-<date>/',
            restarts: 'pveproxy, pvedaemon with the mobile patch',
        },
        note: {
            en: 'Proxmox VE stays free software either way. A subscription funds its development and unlocks the enterprise repository. The mobile option goes one step further than the web one: it changes what the API answers about the support level of the nodes, and the script says so before touching anything.',
            fr: 'Proxmox VE reste un logiciel libre dans tous les cas. Un abonnement finance son développement et donne accès au dépôt entreprise. L’option mobile va un cran plus loin que celle du web : elle change ce que l’API répond sur le niveau de support des nœuds, et le script le dit avant de toucher à quoi que ce soit.',
        },
        terminal: {
            banner: 'proxmox',
            theme: 'orange',
            host: 'root@pve01',
            subtitle: 'Subscription Notice Remover',
            panel: {
                title: 'Patch status',
                lines: [
                    'Detected version: proxmox-widget-toolkit 5.2.8',
                    'Subscription notice: removed',
                    'Popup on mobile: removed',
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
                'Remove the popup on the mobile interface too',
                'Put the mobile interface back as it was',
                'Quit',
            ],
            prompt: 'Choose an option [1-10]:',
        },
    },
    {
        id: 'console-newtab',
        icon: 'browser',
        file: 'pve-console-newtab.sh',
        target: 'pve',
        name: {
            en: 'Console in a new tab',
            fr: 'Console dans un nouvel onglet',
        },
        tagline: {
            en: 'Middle click a console button, it opens in a browser tab instead of a popup window.',
            fr: 'Clic molette sur un bouton console : il s’ouvre dans un onglet du navigateur au lieu d’une fenêtre popup.',
        },
        runsOn: {
            en: 'Proxmox VE host, as root',
            fr: 'Sur l’hôte Proxmox VE, en root',
        },
        compat: 'PVE 8.4.2 → 9.2',
        updated: {
            en: 'Each patched file is now checked on its own, so a partial Proxmox update can simply be re-patched.',
            fr: 'Chaque fichier patché est vérifié séparément : après une mise à jour partielle de Proxmox, il suffit de relancer le patch.',
        },
        points: {
            en: [
                'Middle click on Console, noVNC or xterm.js opens a real browser tab',
                'Middle click on SPICE behaves like a normal click, no useless empty tab',
                'Automatic backup before patching, restore from the menu',
                'Stops and touches nothing if your Proxmox version is not supported',
            ],
            fr: [
                'Clic molette sur Console, noVNC ou xterm.js ouvre un vrai onglet',
                'Clic molette sur SPICE se comporte comme un clic normal, sans onglet vide inutile',
                'Backup automatique avant le patch, restauration depuis le menu',
                'S’arrête sans rien toucher si votre version de Proxmox n’est pas prise en charge',
            ],
        },
        touches: {
            files: [
                { path: '/usr/share/pve-manager/js/pvemanagerlib.js', role: { en: 'console buttons of the interface', fr: 'boutons console de l’interface' } },
                { path: '/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js', role: { en: 'the function that opens the console window', fr: 'la fonction qui ouvre la fenêtre de console' } },
            ],
            backup: '/root/pve-console-newtab-patch-<date>/',
            restarts: 'pveproxy',
        },
        terminal: {
            banner: 'proxmox',
            theme: 'orange',
            host: 'root@pve01',
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
        id: 'wireguard',
        icon: 'shield-lock',
        file: 'lxc-wireguard-server-install.sh',
        target: 'lxc',
        name: {
            en: 'WireGuard VPN server',
            fr: 'Serveur VPN WireGuard',
        },
        tagline: {
            en: 'Installs and manages a WireGuard server inside an LXC, clients and QR codes included.',
            fr: 'Installe et gère un serveur WireGuard dans un LXC, clients et QR codes compris.',
        },
        runsOn: {
            en: 'Inside a Debian or Ubuntu LXC, as root',
            fr: 'Dans un LXC Debian ou Ubuntu, en root',
        },
        compat: 'Debian / Ubuntu LXC',
        updated: {
            en: 'Client list now follows the order of wg0.conf, and the config is remembered after the first run.',
            fr: 'La liste des clients suit l’ordre du wg0.conf, et la configuration est mémorisée après le premier lancement.',
        },
        points: {
            en: [
                'Guided install with three clear network modes',
                'Add, list, show and revoke clients, QR code included',
                'Diagnostic that checks the service, the port, routing and the firewall',
                'Built-in backup and restore, and a clean uninstall',
            ],
            fr: [
                'Installation guidée avec trois modes réseau clairs',
                'Ajouter, lister, afficher et révoquer des clients, QR code compris',
                'Diagnostic qui vérifie le service, le port, le routage et le pare-feu',
                'Sauvegarde et restauration intégrées, et désinstallation propre',
            ],
        },
        touches: {
            files: [
                { path: '/etc/wireguard/', role: { en: 'server config, keys and clients', fr: 'configuration du serveur, clés et clients' } },
                { path: '/etc/systemd/system/wg-server-nft.service', role: { en: 'created, loads the firewall rules at boot', fr: 'créé, charge les règles de pare-feu au démarrage' } },
                { path: '/etc/sysctl.d/99-wireguard-server.conf', role: { en: 'created, turns on IPv4 forwarding', fr: 'créé, active le routage IPv4' } },
            ],
            installs: 'wireguard-tools, nftables, qrencode, iproute2, iputils-ping, curl, ca-certificates',
            backup: '/etc/wireguard/wg0.conf.bak.<date>',
            restarts: 'wg-quick@wg0, wg-server-nft',
        },
        note: {
            en: 'Run it inside the container, not on the Proxmox host. On an unprivileged LXC the script tells you the exact pct commands to run first.',
            fr: 'À lancer dans le conteneur, pas sur l’hôte Proxmox. Sur un LXC non privilégié, le script vous donne les commandes pct exactes à passer avant.',
        },
        terminal: {
            banner: 'wireguard',
            theme: 'red',
            host: 'root@lxc-wireguard',
            subtitle: 'WireGuard server install, setup and management',
            panel: {
                title: 'The three modes',
                lines: [
                    '1) Private: only the WireGuard devices talk to each other.',
                    '2) LAN: clients can reach the local network behind the server.',
                    '3) Full tunnel: client Internet traffic goes through the server.',
                ],
            },
            menu: [
                'Install or reconfigure the WireGuard server',
                'Add or regenerate a client',
                'List the clients and their state',
                'Show or re-scan a client (config + QR)',
                'Delete a client',
                'Diagnostic (check that everything works)',
                'Port forwarding help',
                'Backup and restore of the configuration',
                'Uninstall the WireGuard server',
                'Quit',
            ],
            prompt: 'Your choice [1]:',
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

/* The questions people actually ask before running something as root.
 * Keep the answers to two or three lines. */
const FAQ = [
    {
        q: {
            en: 'Does a Proxmox update undo the changes?',
            fr: 'Une mise à jour de Proxmox annule-t-elle les changements ?',
        },
        a: {
            en: 'For the two scripts that patch the web interface, yes: an update rewrites those files. Run the script again, or turn on the automatic re-apply of the subscription one. The language manager is not affected, it only writes configuration files.',
            fr: 'Pour les deux scripts qui patchent l’interface web, oui : une mise à jour réécrit ces fichiers. Relancez le script, ou activez la réapplication automatique de celui du popup. Le gestionnaire de langue n’est pas concerné, il n’écrit que des fichiers de configuration.',
        },
    },
    {
        q: {
            en: 'How do I undo it?',
            fr: 'Comment revenir en arrière ?',
        },
        a: {
            en: 'Every script keeps a copy before touching anything, and puts it back from its own menu, the restore entry. Nothing else to do. As a last resort, reinstalling the Proxmox package brings the original file back.',
            fr: 'Chaque script garde une copie avant de toucher à quoi que ce soit, et la remet depuis son propre menu, l’entrée de restauration. Rien d’autre à faire. En dernier recours, réinstaller le paquet Proxmox remet le fichier d’origine.',
        },
    },
    {
        q: {
            en: 'Does it get in the way of a Proxmox subscription?',
            fr: 'Est-ce que ça gêne un abonnement Proxmox ?',
        },
        a: {
            en: 'No. These scripts only change files on your own machine, nothing on the Proxmox side. Removing the notice does not unlock the enterprise repository either, that still needs a valid subscription.',
            fr: 'Non. Ces scripts ne modifient que des fichiers sur votre machine, rien du côté de Proxmox. Enlever le popup ne donne pas non plus accès au dépôt entreprise, qui demande toujours un abonnement valide.',
        },
    },
    {
        q: {
            en: 'And on a cluster?',
            fr: 'Et sur un cluster ?',
        },
        a: {
            en: 'The interface patches apply to the node you run them on, so run them on each node. The web interface language is different: it lives in /etc/pve, shared by the whole cluster, so one run is enough. The shell locale stays per node.',
            fr: 'Les patchs d’interface s’appliquent au nœud sur lequel vous les lancez, donc à repasser sur chaque nœud. La langue de l’interface web, elle, vit dans /etc/pve, partagé par tout le cluster : un seul passage suffit. La locale du shell reste propre à chaque nœud.',
        },
    },
];

/* Interface strings. Same rule: { en, fr }. */
const UI = {
    navNews: { en: "What's new", fr: 'Nouveautés' },
    navHowto: { en: 'Get started', fr: 'Démarrer' },
    navScripts: { en: 'Scripts', fr: 'Les scripts' },
    navFaq: 'FAQ',

    langLabel: { en: 'Language', fr: 'Langue' },
    themeLabel: { en: 'Theme', fr: 'Thème' },
    themeSystem: { en: 'System', fr: 'Système' },
    themeLight: { en: 'Light', fr: 'Clair' },
    themeDark: { en: 'Dark', fr: 'Sombre' },

    heroEyebrow: { en: 'Open source shell scripts', fr: 'Scripts shell open source' },
    heroTitle1: { en: 'Handy scripts for everyday', fr: 'Des scripts pratiques pour' },
    heroTitle2: { en: '', fr: 'au quotidien' },
    heroLede: {
        en: 'Each tool is one shell script. Copy a line, paste it in the shell of your Proxmox host or of an LXC, let the menu guide you. Nothing is hidden: the source sits on GitHub, and that is exactly what your server downloads.',
        fr: 'Chaque outil tient dans un seul script shell. Copiez une ligne, collez-la dans le shell de votre hôte Proxmox ou d’un LXC, laissez le menu vous guider. Rien n’est caché : le code est sur GitHub, et c’est exactement ce que votre serveur télécharge.',
    },
    heroBtnScripts: { en: 'Browse the scripts', fr: 'Voir les scripts' },
    heroBtnSource: { en: 'Read the source', fr: 'Lire le code' },
    factScripts: { en: 'scripts ready to run', fr: 'scripts prêts à lancer' },
    factDeps: { en: 'dependency to install', fr: 'dépendance à installer' },
    factLicense: { en: 'open source, no fork of Proxmox', fr: 'open source, aucun fork de Proxmox' },

    trust1Title: { en: 'Read it before you run it', fr: 'Lisez-le avant de le lancer' },
    trust1Body: {
        en: 'Each card links to the exact file on GitHub. Same file, same branch, same content your server fetches.',
        fr: 'Chaque carte renvoie au fichier exact sur GitHub. Même fichier, même branche, même contenu que celui téléchargé par votre serveur.',
    },
    trust2Title: { en: 'Served by GitHub, not by this site', fr: 'Servi par GitHub, pas par ce site' },
    trust2Body: {
        en: 'This page only shows you the command. The download always comes from raw.githubusercontent.com.',
        fr: 'Cette page ne fait qu’afficher la commande. Le téléchargement vient toujours de raw.githubusercontent.com.',
    },
    trust3Title: { en: 'Every change can be undone', fr: 'Tout changement est réversible' },
    trust3Body: {
        en: 'Scripts that touch a Proxmox file save a copy first, and put it back from their own menu.',
        fr: 'Les scripts qui touchent à un fichier Proxmox en gardent une copie, et la remettent depuis leur propre menu.',
    },

    scriptsTitle: { en: 'The scripts', fr: 'Les scripts' },
    scriptsLede: {
        en: 'Pick one, copy its line, paste it as root, on the Proxmox host or inside the LXC it targets. Each script opens a menu and waits for you: nothing runs on its own.',
        fr: 'Choisissez-en un, copiez sa ligne, collez-la en root, sur l’hôte Proxmox ou dans le LXC concerné. Chaque script ouvre un menu et vous attend : rien ne s’exécute tout seul.',
    },
    cardRunOn: { en: 'Runs on', fr: 'S’exécute sur' },
    cardCopyLabel: { en: 'Copy this line into your shell', fr: 'Copiez cette ligne dans votre shell' },
    cardCopy: { en: 'Copy the command', fr: 'Copier la commande' },
    cardCopied: { en: 'Copied', fr: 'Copié' },
    cardSource: { en: 'Read the source on GitHub', fr: 'Lire le code sur GitHub' },
    cardLink: { en: 'Copy the link to this script', fr: 'Copier le lien vers ce script' },
    touchesTitle: { en: 'What this script touches', fr: 'Ce que ce script touche' },
    touchesInstalls: { en: 'Installs', fr: 'Installe' },
    touchesBackup: { en: 'Copy kept in', fr: 'Copie gardée dans' },
    touchesRestarts: { en: 'Restarts', fr: 'Redémarre' },
    copyOk: { en: 'Command copied, paste it as root', fr: 'Commande copiée, collez-la en root' },
    linkOk: { en: 'Link to this script copied', fr: 'Lien vers ce script copié' },
    copyFail: { en: 'Copy failed, select the line by hand', fr: 'Copie impossible, sélectionnez la ligne à la main' },

    newsTitle: { en: "What's new", fr: 'Quoi de neuf' },
    newsLede: {
        en: 'The latest improvement on each script. Everything else lives in the commit history.',
        fr: 'La dernière amélioration de chaque script. Tout le reste vit dans l’historique des commits.',
    },
    newsBadge: { en: 'Latest', fr: 'Nouveau' },

    howtoTitle: { en: 'Get started in three steps', fr: 'Démarrer en trois étapes' },
    howtoLede: {
        en: 'No installer, no package to add, nothing left behind on your system.',
        fr: 'Aucun installeur, aucun paquet à ajouter, rien qui traîne sur votre système.',
    },
    step1Title: { en: 'Open a root shell', fr: 'Ouvrez un shell root' },
    step1Body: {
        en: 'From the Proxmox web interface, Shell on your node, or Console on the LXC a script targets. An SSH session as root works too. Keep it open while the script runs.',
        fr: 'Depuis l’interface web Proxmox, Shell sur votre nœud, ou Console sur le LXC visé par un script. Une session SSH en root marche aussi. Gardez-la ouverte pendant l’exécution.',
    },
    step2Title: { en: 'Paste the line', fr: 'Collez la ligne' },
    step2Body: {
        en: 'Use the copy button on the card. The line fetches the script from GitHub and runs it, it installs nothing.',
        fr: 'Utilisez le bouton copier de la carte. La ligne récupère le script depuis GitHub et l’exécute, elle n’installe rien.',
    },
    step3Title: { en: 'Follow the menu', fr: 'Suivez le menu' },
    step3Body: {
        en: 'Scripts that modify Proxmox ask for a confirmation and save a copy first. The same menu puts it back.',
        fr: 'Les scripts qui modifient Proxmox demandent confirmation et gardent une copie avant. Le même menu la remet en place.',
    },
    howtoNote: {
        en: 'Scripts that restart pveproxy can take up to a minute: Proxmox refreshes its cluster certificates on start. The web interface is unreachable meanwhile, it is expected.',
        fr: 'Les scripts qui redémarrent pveproxy peuvent mettre jusqu’à une minute : Proxmox régénère ses certificats de cluster au démarrage. L’interface web est injoignable pendant ce temps, c’est normal.',
    },

    faqTitle: 'FAQ',
    faqLede: {
        en: 'What comes up most often before running one of these on a live server.',
        fr: 'Ce qui revient le plus souvent avant de lancer un de ces scripts sur un serveur en service.',
    },

    footerBy: { en: 'Built by', fr: 'Réalisé par' },
    footerDisclaimer: {
        en: 'Community project, not affiliated with, endorsed by or sponsored by Proxmox Server Solutions GmbH. Proxmox and the Proxmox logo are trademarks of Proxmox Server Solutions GmbH. These scripts are provided as is, without warranty: read them before running them.',
        fr: 'Projet communautaire, sans aucun lien avec Proxmox Server Solutions GmbH, ni approuvé ni sponsorisé par eux. Proxmox et le logo Proxmox sont des marques de Proxmox Server Solutions GmbH. Ces scripts sont fournis tels quels, sans garantie : lisez-les avant de les lancer.',
    },
    footerIcons: { en: 'Icons by', fr: 'Icônes par' },
    footerRepo: { en: 'Repository', fr: 'Dépôt' },
    footerIssues: { en: 'Report a problem', fr: 'Signaler un problème' },
    footerProxmox: { en: 'Proxmox VE', fr: 'Proxmox VE' },
};
