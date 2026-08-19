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
 *   note      optional warning, shown in a quieter box
 *   terminal  what the fake terminal shows, see below
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
 * translated: the Proxmox scripts print English, the WireGuard one French.
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
            en: 'New script. Optional APT hook re-applies the patch after a package update.',
            fr: 'Nouveau script. Un hook APT optionnel réapplique le patch après une mise à jour.',
        },
        points: {
            en: [
                'No more popup at every login',
                'Package versions, system report, APT refresh and add repository keep working',
                'Optional automatic re-apply after a package update',
                'Automatic backup before patching, restore from the menu',
            ],
            fr: [
                'Plus de popup à chaque connexion',
                'Versions des paquets, rapport système, actualisation APT et ajout de dépôt continuent de fonctionner',
                'Réapplication automatique optionnelle après une mise à jour',
                'Backup automatique avant le patch, restauration depuis le menu',
            ],
        },
        note: {
            en: 'Proxmox VE stays free software either way. A subscription funds its development and unlocks the enterprise repository.',
            fr: 'Proxmox VE reste un logiciel libre dans tous les cas. Un abonnement finance son développement et donne accès au dépôt entreprise.',
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
        note: {
            en: 'Run it inside the container, not on the Proxmox host. On an unprivileged LXC the script tells you the exact pct commands to run first.',
            fr: 'À lancer dans le conteneur, pas sur l’hôte Proxmox. Sur un LXC non privilégié, le script vous donne les commandes pct exactes à passer avant.',
        },
        terminal: {
            banner: 'wireguard',
            theme: 'red',
            host: 'root@lxc-wireguard',
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

/* Interface strings. Same rule: { en, fr }. */
const UI = {
    navNews: { en: "What's new", fr: 'Nouveautés' },
    navHowto: { en: 'Get started', fr: 'Démarrer' },
    navScripts: { en: 'Scripts', fr: 'Les scripts' },

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
    copyOk: { en: 'Command copied, paste it as root', fr: 'Commande copiée, collez-la en root' },
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
