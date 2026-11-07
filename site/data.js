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
 *   target    "pve" (Proxmox host) or "lxc" (inside a container), picks the
 *             group the card is listed in and its icon
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
 * touches.restarts optional, the services it restarts
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
            en: 'Optional, Proxmox VE 9 only: its mobile interface follows the default language too, instead of always starting in English.',
            fr: 'Optionnel, Proxmox VE 9 uniquement : son interface mobile suit aussi la langue par défaut, au lieu de démarrer toujours en anglais.',
        },
        points: {
            en: [
                'Sets the system locale and the web interface language together',
                'Optional, Proxmox VE 9 only: its mobile interface follows that default too, kept after updates if you want',
                '29 languages, the script interface speaks them too',
                'Optional timezone and NTP setup',
                'Warns instead of writing a language Proxmox would silently drop',
            ],
            fr: [
                'Règle la locale système et la langue de l’interface web ensemble',
                'Optionnel, Proxmox VE 9 uniquement : son interface mobile suit aussi ce défaut, gardé après les mises à jour si vous voulez',
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
                { path: '/usr/share/pve-yew-mobile-gui/index.html.tpl', role: { en: 'a few lines added, only if you apply the default to the mobile interface of Proxmox VE 9', fr: 'quelques lignes ajoutées, seulement si vous appliquez le défaut à l’interface mobile de Proxmox VE 9' } },
                { path: '/etc/apt/apt.conf.d/99-pve-default-language', role: { en: 'optional, re-applies the mobile setting after an update', fr: 'optionnel, réapplique le réglage mobile après une mise à jour' } },
                { path: '/usr/local/lib/pve-default-language/mobile.py', role: { en: 'optional, the program the APT hook runs', fr: 'optionnel, le programme lancé par le hook APT' } },
            ],
            backup: '/root/pve-default-language-<date>/',
            restarts: 'pveproxy',
        },
        demo: {
            file: 'default-language.webp',
            alt: {
                en: 'As shipped, the login page and the interface start in English; once the script set French as the default, both start in French',
                fr: 'D’origine, la page de connexion et l’interface démarrent en anglais ; une fois le français réglé par le script, les deux démarrent en français',
            },
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
                'Apply the default language to the mobile interface',
                'Remove that setting from the mobile interface',
                'Re-apply the mobile setting automatically after an update',
                'Stop re-applying the mobile setting automatically',
                'Quit',
            ],
            prompt: 'Choose an option [1-11]:',
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
            en: 'Separate option for the mobile interface of Proxmox VE 9, which is another application and keeps its own popup.',
            fr: 'Option séparée pour l’interface mobile de Proxmox VE 9, une autre application qui garde son propre popup.',
        },
        points: {
            en: [
                'No more popup at every login',
                'Package versions, system report, APT refresh and add repository keep working',
                'Separate option for the mobile interface of Proxmox VE 9, patched on its own with its own way back',
                'Optional automatic re-apply after a package update',
                'Automatic backup before patching, restore from the menu',
            ],
            fr: [
                'Plus de popup à chaque connexion',
                'Versions des paquets, rapport système, actualisation APT et ajout de dépôt continuent de fonctionner',
                'Option séparée pour l’interface mobile de Proxmox VE 9, patchée à part avec son propre retour arrière',
                'Réapplication automatique optionnelle après une mise à jour',
                'Backup automatique avant le patch, restauration depuis le menu',
            ],
        },
        touches: {
            files: [
                { path: '/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js', role: { en: 'one line changed, the one that shows the popup', fr: 'une ligne modifiée, celle qui affiche le popup' } },
                { path: '/usr/share/perl5/PVE/API2Tools.pm', role: { en: 'one line changed, only if you patch the mobile interface of Proxmox VE 9 too', fr: 'une ligne modifiée, seulement si vous patchez aussi l’interface mobile de Proxmox VE 9' } },
                { path: '/etc/apt/apt.conf.d/99-pve-remove-subscription-notice', role: { en: 'created only if you turn on the automatic re-apply', fr: 'créé seulement si vous activez la réapplication automatique' } },
            ],
            backup: '/root/pve-subscription-notice-patch-<date>/',
            restarts: 'pveproxy, pvedaemon with the mobile patch',
        },
        note: {
            en: 'Proxmox VE stays free software either way. A subscription funds its development and unlocks the enterprise repository. The mobile option only concerns Proxmox VE 9, whose mobile interface is a separate application, and it goes one step further than the web one: it changes what the API answers about the support level of the nodes. The script says all of this before touching anything, and refuses the option on Proxmox VE 8.',
            fr: 'Proxmox VE reste un logiciel libre dans tous les cas. Un abonnement finance son développement et donne accès au dépôt entreprise. L’option mobile ne concerne que Proxmox VE 9, dont l’interface mobile est une application distincte, et elle va un cran plus loin que celle du web : elle change ce que l’API répond sur le niveau de support des nœuds. Le script dit tout cela avant de toucher à quoi que ce soit, et refuse l’option sur Proxmox VE 8.',
        },
        demo: {
            file: 'subscription-notice.webp',
            alt: {
                en: 'As shipped, the No valid subscription window opens after every login; with the script, the login goes straight to the interface',
                fr: 'D’origine, la fenêtre « No valid subscription » s’ouvre après chaque connexion ; avec le script, la connexion mène directement à l’interface',
            },
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
            en: 'The middle click of the left tree now also works on a node: its shell opens in a new tab.',
            fr: 'Le clic molette de l’arborescence de gauche marche aussi sur un nœud : son shell s’ouvre dans un nouvel onglet.',
        },
        points: {
            en: [
                'Middle click on Console, noVNC or xterm.js opens a real browser tab',
                'Middle click on SPICE behaves like a normal click, no useless empty tab',
                'Separate option: middle click on a node or guest of the left tree opens its console in a tab',
                'Automatic backup and restore, optional re-apply after updates',
                'Stops and touches nothing if your Proxmox version is not supported',
            ],
            fr: [
                'Clic molette sur Console, noVNC ou xterm.js ouvre un vrai onglet',
                'Clic molette sur SPICE se comporte comme un clic normal, sans onglet vide inutile',
                'Option séparée : clic molette sur un nœud, une VM ou un LXC de l’arborescence ouvre sa console dans un onglet',
                'Backup et restauration, réapplication optionnelle après les mises à jour',
                'S’arrête sans rien toucher si votre version de Proxmox n’est pas prise en charge',
            ],
        },
        touches: {
            files: [
                { path: '/usr/share/pve-manager/js/pvemanagerlib.js', role: { en: 'console buttons of the interface', fr: 'boutons console de l’interface' } },
                { path: '/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js', role: { en: 'the function that opens the console window', fr: 'la fonction qui ouvre la fenêtre de console' } },
                { path: '/etc/apt/apt.conf.d/99-pve-console-newtab', role: { en: 'optional, re-applies the patches in place after an update', fr: 'optionnel, réapplique les patchs en place après une mise à jour' } },
                { path: '/usr/local/lib/pve-console-newtab/patch.py', role: { en: 'optional, the program the APT hook runs', fr: 'optionnel, le programme lancé par le hook APT' } },
            ],
            backup: '/root/pve-console-newtab-patch-<date>/',
            restarts: 'pveproxy',
        },
        demo: {
            file: 'console-newtab.webp',
            alt: {
                en: 'As shipped, a middle click on Console does nothing and a click opens a separate window; with the script, a middle click on Console or on a guest of the tree opens the console in a new tab',
                fr: 'D’origine, un clic molette sur Console ne fait rien et un clic ouvre une fenêtre séparée ; avec le script, un clic molette sur Console ou sur une VM de l’arborescence ouvre la console dans un nouvel onglet',
            },
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
                'Add the middle click on the nodes, VM and LXC of the resource tree',
                'Re-apply automatically after an update',
                'Stop re-applying automatically',
                'Quit',
            ],
            prompt: 'Choose an option [1-9]:',
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
    {
        id: 'fastfetch-motd',
        icon: 'terminal',
        file: 'pve-fastfetch-motd.sh',
        target: 'pve',
        name: {
            en: 'Fastfetch summary at login',
            fr: 'Résumé Fastfetch à la connexion',
        },
        tagline: {
            en: 'Replaces the old Debian MOTD with a live summary of the node, printed when a root shell opens.',
            fr: 'Remplace l’ancien MOTD Debian par un résumé à jour du nœud, affiché à l’ouverture d’un shell root.',
        },
        runsOn: {
            en: 'Proxmox VE host, as root',
            fr: 'Sur l’hôte Proxmox VE, en root',
        },
        compat: 'PVE 8.x / 9.x',
        updated: {
            en: 'New script. Latest stable Fastfetch, optional HTTPS certificate check, or paste your own configuration.',
            fr: 'Nouveau script. Dernière version stable de Fastfetch, contrôle de certificat HTTPS optionnel, ou collez votre propre configuration.',
        },
        points: {
            en: [
                'Installs the latest stable Fastfetch release, for your CPU architecture',
                'PVE version, CPU usage and temperature, ZFS health, bridge, IPs, Fail2ban jails',
                'Optional expiry check of the certificate served over HTTPS, never a private key',
                'Or paste your own config.jsonc, checked by Fastfetch before it replaces anything',
                'Two removal levels: stop the display, or remove everything and uninstall the package',
            ],
            fr: [
                'Installe la dernière version stable de Fastfetch, pour votre architecture',
                'Version PVE, charge et température CPU, santé ZFS, bridge, IP, prisons Fail2ban',
                'Contrôle optionnel de l’expiration du certificat servi en HTTPS, jamais de clé privée',
                'Ou collez votre propre config.jsonc, vérifiée par Fastfetch avant de remplacer quoi que ce soit',
                'Deux niveaux de suppression : arrêter l’affichage, ou tout retirer et désinstaller le paquet',
            ],
        },
        touches: {
            files: [
                { path: '/root/.config/fastfetch/config.jsonc', role: { en: 'created, what the summary shows', fr: 'créé, le contenu du résumé' } },
                { path: '/etc/profile.d/99-fastfetch-motd.sh', role: { en: 'created, prints the summary in interactive root shells', fr: 'créé, affiche le résumé dans les shells root interactifs' } },
                { path: '/etc/motd', role: { en: 'emptied, saved beforehand and put back on removal', fr: 'vidé, sauvegardé avant et remis lors de la suppression' } },
                { path: '/etc/update-motd.d/10-uname', role: { en: 'execute bit removed, given back on removal', fr: 'droit d’exécution retiré, rendu lors de la suppression' } },
            ],
            installs: 'fastfetch',
            backup: '/root/pve-fastfetch-motd-backup-original/',
        },
        note: {
            en: 'The certificate module is only added if you enter a FQDN, and it reads the public certificate presented over HTTPS, nothing else. Open a new root shell to see the result.',
            fr: 'Le module certificat n’est ajouté que si vous saisissez un FQDN, et il lit le certificat public présenté en HTTPS, rien d’autre. Ouvrez un nouveau shell root pour voir le résultat.',
        },
        terminal: {
            banner: 'proxmox',
            theme: 'orange',
            host: 'root@pve01',
            subtitle: 'Fastfetch MOTD',
            panel: {
                title: 'Status',
                lines: [
                    'Fastfetch: installed 2.67.1',
                    'Configuration: managed by this script',
                    'Login display: enabled',
                    'Old Debian MOTD: disabled',
                ],
            },
            menu: [
                'Install / update Fastfetch and the login display',
                'Configure the HTTPS certificate module (FQDN)',
                'Use my own configuration (paste it)',
                'Preview the Fastfetch output',
                'Show status',
                'Disable the display on every shell session (keep Fastfetch)',
                'Remove everything (display, configuration and Fastfetch)',
                'Quit',
            ],
            prompt: 'Choose an option [1-8]:',
        },
    },
    {
        id: 'expand-node-tree',
        icon: 'list-tree',
        file: 'pve-expand-node-tree.sh',
        target: 'pve',
        name: {
            en: 'Default panel layout',
            fr: 'Disposition des panneaux par défaut',
        },
        tagline: {
            en: 'Expands the resource tree and collapses the Logs panel by default, no more chevrons to click at every login.',
            fr: 'Déplie l’arborescence et replie le panneau Logs par défaut, plus de chevrons à cliquer à chaque connexion.',
        },
        runsOn: {
            en: 'Proxmox VE host, as root',
            fr: 'Sur l’hôte Proxmox VE, en root',
        },
        compat: 'PVE 8.x / 9.x',
        updated: {
            en: 'New script. Every node of the resource tree opens at login, and the Logs panel can start collapsed.',
            fr: 'Nouveau script. Chaque nœud de l’arborescence s’ouvre à la connexion, et le panneau Logs peut démarrer replié.',
        },
        points: {
            en: [
                'Each node opens automatically on the default Server View',
                'Pools, storages, VMs and containers stay exactly as they are',
                'Separate option collapses the Logs panel (Tasks tab) by default',
                'Same effect as clicking every chevron by hand, done once for good',
                'Automatic backup and restore, optional re-apply after updates',
            ],
            fr: [
                'Chaque nœud s’ouvre automatiquement sur la vue Serveur par défaut',
                'Pools, stockages, VM et conteneurs restent exactement comme ils sont',
                'Option séparée pour replier le panneau Logs (onglet Tâches) par défaut',
                'Même effet que cliquer chaque chevron à la main, fait une bonne fois pour toutes',
                'Backup et restauration, réapplication optionnelle après les mises à jour',
            ],
        },
        touches: {
            files: [
                { path: '/usr/share/pve-manager/js/pvemanagerlib.js', role: { en: 'a few lines added: the ones that build each node of the tree, and the ones for the Logs panel if that option is used', fr: 'quelques lignes ajoutées : celles qui construisent chaque nœud de l’arborescence, et celles du panneau Logs si cette option est utilisée' } },
                { path: '/etc/apt/apt.conf.d/99-pve-expand-node-tree', role: { en: 'optional, re-applies the patches in place after an update', fr: 'optionnel, réapplique les patchs en place après une mise à jour' } },
                { path: '/usr/local/lib/pve-expand-node-tree/patch.py', role: { en: 'optional, the program the APT hook runs', fr: 'optionnel, le programme lancé par le hook APT' } },
            ],
            backup: '/root/pve-expand-node-tree-patch-<date>/',
            restarts: 'pveproxy',
        },
        demo: {
            file: 'expand-node-tree.webp',
            alt: {
                en: 'As shipped, each node and the Logs panel have to be set by hand after login; with the script the page opens that way',
                fr: 'D’origine, chaque nœud et le panneau Logs se règlent à la main après la connexion ; avec le script la page s’ouvre directement ainsi',
            },
        },
        terminal: {
            banner: 'proxmox',
            theme: 'orange',
            host: 'root@pve01',
            subtitle: 'Default Panel Layout',
            panel: {
                title: 'Patch status',
                lines: [
                    'Detected version: pve-manager 9.0.18',
                    'Nodes expanded by default: active',
                    'Logs panel collapsed by default: active',
                    'Automatic re-apply: enabled',
                ],
            },
            menu: [
                'Apply patch (automatic backup included)',
                'Restore latest backup',
                'Restore from selected backup',
                'Show patch status',
                'List backups',
                'Collapse the Logs panel by default',
                'Keep the Logs panel expanded by default',
                'Re-apply automatically after an update',
                'Stop re-applying automatically',
                'Quit',
            ],
            prompt: 'Choose an option [1-10]:',
        },
    },
    {
        id: 'xterm-scrollback',
        icon: 'history',
        file: 'pve-xtermjs-scrollback.sh',
        target: 'pve',
        name: {
            en: 'Console scrollback',
            fr: 'Historique des consoles',
        },
        tagline: {
            en: 'Raises the history of every web console from 1000 lines to the size you choose, for all your browsers at once.',
            fr: 'Passe l’historique de toutes les consoles web de 1000 lignes à la taille de votre choix, pour tous vos navigateurs à la fois.',
        },
        runsOn: {
            en: 'Proxmox VE host, as root',
            fr: 'Sur l’hôte Proxmox VE, en root',
        },
        compat: 'PVE 8.x / 9.x',
        updated: {
            en: 'New script. The xterm.js consoles keep the history size you pick instead of 1000 lines.',
            fr: 'Nouveau script. Les consoles xterm.js gardent la taille d’historique de votre choix au lieu de 1000 lignes.',
        },
        points: {
            en: [
                'Five ready-made sizes up to 250000 lines, or type your own number, changeable later',
                'Applies to the host shell, containers and VM serial consoles',
                'Set once on the server: no browser setting to redo on every computer',
                'One line changed, matched exactly: a changed file is reported, never patched blindly',
                'No restart, automatic backup and restore, optional re-apply after updates',
            ],
            fr: [
                'Cinq tailles prêtes jusqu’à 250000 lignes, ou votre propre nombre, modifiable ensuite',
                'S’applique au shell de l’hôte, aux conteneurs et aux consoles série des VM',
                'Réglé une fois sur le serveur : plus de réglage à refaire dans chaque navigateur',
                'Une seule ligne modifiée, cherchée à l’identique : un fichier différent est signalé, jamais patché à l’aveugle',
                'Aucun redémarrage, backup et restauration, réapplication optionnelle après les mises à jour',
            ],
        },
        touches: {
            files: [
                { path: '/usr/share/pve-xtermjs/util.js', role: { en: 'one line changed: the default options given to every console', fr: 'une ligne modifiée : les options par défaut données à chaque console' } },
                { path: '/etc/apt/apt.conf.d/99-pve-xtermjs-scrollback', role: { en: 'optional, re-applies the patch after an update', fr: 'optionnel, réapplique le patch après une mise à jour' } },
                { path: '/usr/local/lib/pve-xtermjs-scrollback/patch.py', role: { en: 'optional, the program the APT hook runs', fr: 'optionnel, le programme lancé par le hook APT' } },
            ],
            backup: '/root/pve-xtermjs-scrollback-patch-<date>/',
        },
        note: {
            en: 'A full console takes about 1 MB per 1000 lines in the browser at 80 columns (100000 lines: about 100 MB), per open tab. A value saved in a browser still wins over the one you pick. Updates of the pve-xtermjs package overwrite the patch: run the script again afterwards, unless the automatic re-apply is enabled.',
            fr: 'Une console pleine occupe environ 1 Mo par 1000 lignes dans le navigateur en 80 colonnes (100000 lignes : environ 100 Mo), par onglet ouvert. Une valeur enregistrée dans un navigateur reste prioritaire sur celle que vous choisissez. Les mises à jour du paquet pve-xtermjs écrasent le patch : relancez le script ensuite, sauf si la réapplication automatique est activée.',
        },
        demo: {
            file: 'xterm-scrollback.webp',
            alt: {
                en: '5000 numbered lines printed in a console: as shipped, scrolling up stops at line 3963; with the script, it goes back to line 1',
                fr: '5000 lignes numérotées affichées dans une console : d’origine, on ne remonte que jusqu’à la ligne 3963 ; avec le script, jusqu’à la ligne 1',
            },
        },
        terminal: {
            banner: 'proxmox',
            theme: 'orange',
            host: 'root@pve01',
            subtitle: 'Console Scrollback',
            panel: {
                title: 'Patch status',
                lines: [
                    'Detected version: pve-xtermjs 6.0.0-2',
                    'Console scrollback: 100000 lines (patch active)',
                    'Automatic re-apply: enabled',
                ],
            },
            menu: [
                'Apply patch or change the number of lines (automatic backup included)',
                'Restore latest backup',
                'Restore from selected backup',
                'Show patch status',
                'List backups',
                'Generate test lines (check the console history)',
                'Re-apply automatically after an update',
                'Stop re-applying automatically',
                'Quit',
            ],
            prompt: 'Choose an option [1-9]:',
        },
    },
    {
        id: 'xterm-tab-title',
        icon: 'browser',
        file: 'pve-xterm-tab-title.sh',
        target: 'pve',
        name: {
            en: 'Console tab title',
            fr: 'Titre des onglets de console',
        },
        tagline: {
            en: 'The tab of an xterm.js console shows the guest it belongs to, not only the node.',
            fr: 'L’onglet d’une console xterm.js affiche la VM ou le conteneur, pas seulement le noeud.',
        },
        runsOn: {
            en: 'Proxmox VE host, as root',
            fr: 'Sur l’hôte Proxmox VE, en root',
        },
        compat: 'PVE 8.x / 9.x',
        updated: {
            en: 'Works again with pve-xtermjs 6.0.0-3, and can re-apply itself after updates.',
            fr: 'Fonctionne à nouveau avec pve-xtermjs 6.0.0-3, et peut se réappliquer après les mises à jour.',
        },
        points: {
            en: [
                'Tab reads ID (Name) · Node · PVE, for example 101 (web01) · pve02 · PVE',
                'Containers and VMs in xterm.js, and the node shell (Node · PVE)',
                'Two lines added, matched exactly: a different file is reported, never patched blindly',
                'Automatic backup before patching, restore from the menu',
                'Optional automatic re-apply after a pve-xtermjs update',
            ],
            fr: [
                'L’onglet affiche ID (Nom) · Noeud · PVE, par exemple 101 (web01) · pve02 · PVE',
                'Conteneurs et VM en xterm.js, et le shell du noeud (Noeud · PVE)',
                'Deux lignes ajoutées, cherchées à l’identique : un fichier différent est signalé, jamais patché à l’aveugle',
                'Backup automatique avant le patch, restauration depuis le menu',
                'Réapplication automatique optionnelle après une mise à jour de pve-xtermjs',
            ],
        },
        touches: {
            files: [
                { path: '/usr/share/pve-xtermjs/main.js', role: { en: 'two lines added: a comment and the title of the console tab', fr: 'deux lignes ajoutées : un commentaire et le titre de l’onglet de console' } },
                { path: '/etc/apt/apt.conf.d/99-pve-xterm-tab-title', role: { en: 'optional, re-applies the patch after an update', fr: 'optionnel, réapplique le patch après une mise à jour' } },
                { path: '/usr/local/lib/pve-xterm-tab-title/patch.py', role: { en: 'optional, the program the APT hook runs', fr: 'optionnel, le programme lancé par le hook APT' } },
            ],
            backup: '/root/pve-xterm-tab-title-patch-<date>/',
        },
        note: {
            en: 'Open a new console tab after patching: a tab opened before keeps its title. Only xterm.js consoles are changed, not noVNC or SPICE. Updates of the pve-xtermjs package overwrite the patch: run the script again afterwards, unless the automatic re-apply is enabled.',
            fr: 'Ouvrez un nouvel onglet de console après le patch : un onglet ouvert avant garde son titre. Seules les consoles xterm.js sont modifiées, pas noVNC ni SPICE. Les mises à jour du paquet pve-xtermjs écrasent le patch : relancez le script ensuite, sauf si la réapplication automatique est activée.',
        },
        demo: {
            file: 'xterm-tab-title.webp',
            alt: {
                en: 'As shipped, every console tab reads pve01 - Proxmox Console; with the script, each tab names its guest, for example 200 (pihole) · pve01 · PVE',
                fr: 'D’origine, chaque onglet de console affiche pve01 - Proxmox Console ; avec le script, chaque onglet nomme sa machine, par exemple 200 (pihole) · pve01 · PVE',
            },
        },
        terminal: {
            banner: 'proxmox',
            theme: 'orange',
            host: 'root@pve01',
            subtitle: 'Console Tab Title',
            panel: {
                title: 'Patch status',
                lines: [
                    'Detected version: pve-xtermjs 6.0.0-3',
                    'xterm.js tab title: ID (Name) · Node · PVE (patch active)',
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
        id: 'modern-theme',
        icon: 'palette',
        file: 'pve-modern-theme.sh',
        target: 'pve',
        name: {
            en: 'Modern theme',
            fr: 'Thème moderne',
        },
        tagline: {
            en: 'Modern themes for the web interface, 5 colors in light, dark and auto, picked from the Color Theme menu.',
            fr: 'Des thèmes modernes pour l’interface web, 5 couleurs en clair, sombre et auto, à choisir dans le menu Thème de couleur.',
        },
        runsOn: {
            en: 'Proxmox VE host, as root',
            fr: 'Sur l’hôte Proxmox VE, en root',
        },
        compat: 'PVE 9.x',
        updated: {
            en: 'New script. Modern themes in 5 colors, new icons, chart colors and fixes of the interface.',
            fr: 'Nouveau script. Des thèmes modernes en 5 couleurs, de nouvelles icônes, des graphiques colorés et des corrections de l’interface.',
        },
        points: {
            en: [
                'Orange, blue, violet, green and pink, each in Auto, Light and Dark',
                'Rounded cards, tinted title bars, modern icons and status dots, colored charts',
                'A default theme for the whole server, login page included',
                'Status panel sized to its content; options: storage sizes in TiB like Windows, Start button of the console of a stopped guest',
                'Blocks matched exactly, automatic backup, full uninstall that keeps the changes of other scripts',
            ],
            fr: [
                'Orange, bleu, violet, vert et rose, chacun en Auto, Clair et Sombre',
                'Cartes arrondies, barres de titre teintées, icônes modernes et pastilles d’état, graphiques colorés',
                'Un thème par défaut pour tout le serveur, page de connexion comprise',
                'Panneau de statut à la taille de son contenu ; en option, tailles des stockages en Tio comme Windows et bouton Démarrer de la console d’un invité arrêté',
                'Blocs cherchés à l’identique, backup automatique, désinstallation complète qui garde les modifications des autres scripts',
            ],
        },
        touches: {
            files: [
                { path: '/usr/share/javascript/proxmox-widget-toolkit/themes/theme-modern-*.css', role: { en: '15 theme files added (5 colors, auto, light and dark)', fr: '15 fichiers de thème ajoutés (5 couleurs, auto, clair et sombre)' } },
                { path: '/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js', role: { en: 'theme entries of the Color Theme menu, chart colors read from the theme', fr: 'entrées du menu Thème de couleur, couleurs des graphiques lues dans le thème' } },
                { path: '/usr/share/pve-manager/js/pvemanagerlib.js', role: { en: 'collapse button of the Logs panel, status panel sized to its content, storage sizes in TiB when enabled', fr: 'bouton de repli du panneau Journaux, panneau de statut à la taille de son contenu, tailles en Tio si activées' } },
                { path: '/usr/share/pve-xtermjs/style.css', role: { en: 'Start button of the console of a stopped guest, when enabled', fr: 'bouton Démarrer de la console d’un invité arrêté, si activé' } },
                { path: '/usr/share/perl5/PVE/Service/pveproxy.pm', role: { en: 'default theme of the server, when one is chosen', fr: 'thème par défaut du serveur, s’il est choisi' } },
                { path: '/etc/apt/apt.conf.d/99-pve-modern-theme', role: { en: 'optional, re-applies the changes after an update', fr: 'optionnel, réapplique les modifications après une mise à jour' } },
                { path: '/usr/local/lib/pve-modern-theme/engine.py', role: { en: 'optional, the program the APT hook runs', fr: 'optionnel, le programme lancé par le hook APT' } },
            ],
            backup: '/root/pve-modern-theme-patch-<date>/',
            restarts: 'pveproxy',
        },
        note: {
            en: 'Each browser picks its theme in Color Theme; the ones that made no choice follow the default theme of the server. Browsers can keep the old copy of the files: check in a private window, then clear the site data. Updates of proxmox-widget-toolkit and pve-manager remove the themes from the menu until the script runs again, unless the APT hook is enabled.',
            fr: 'Chaque navigateur choisit son thème dans Thème de couleur ; ceux qui n’ont rien choisi suivent le thème par défaut du serveur. Les navigateurs peuvent garder l’ancienne copie des fichiers : vérifiez dans une fenêtre privée, puis effacez les données du site. Les mises à jour de proxmox-widget-toolkit et pve-manager retirent les thèmes du menu jusqu’à ce que le script soit relancé, sauf si le hook APT est activé.',
        },
        demo: {
            file: 'modern-theme.webp',
            alt: {
                en: 'Proxmox VE as shipped, then with the Modern theme in orange, blue, violet, green and pink',
                fr: 'Proxmox VE d’origine, puis avec le thème Modern en orange, bleu, violet, vert et rose',
            },
        },
        terminal: {
            banner: 'proxmox',
            theme: 'orange',
            host: 'root@pve01',
            subtitle: 'Modern Theme',
            panel: {
                title: 'Status',
                lines: [
                    'Detected version: pve-manager 9.2.24 · proxmox-widget-toolkit 5.2.10',
                    'Theme files: installed',
                    'Themes in the "Color Theme" menu: in place',
                ],
            },
            menu: [
                'Install or update the themes (automatic backup included)',
                'Restore latest backup',
                'Restore from selected backup',
                'Show status',
                'List backups',
                'Option: storage sizes in TiB like Windows (enable or disable)',
                'Option: Start button in the console of a stopped guest (enable or disable)',
                'Default theme of the server (login page included)',
                'Re-apply automatically after an update',
                'Stop re-applying automatically',
                'Uninstall everything',
                'Quit',
            ],
            prompt: 'Choose an option [1-12]:',
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
    railLabel: { en: 'Jump to a script', fr: 'Aller à un script' },

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
    groupPve: { en: 'On the Proxmox VE host', fr: 'Sur l’hôte Proxmox VE' },
    groupPveBody: {
        en: 'Run these as root on the host itself: they change Proxmox VE.',
        fr: 'À lancer en root sur l’hôte lui-même : ils modifient Proxmox VE.',
    },
    groupPveRail: 'Proxmox VE',
    groupLxc: { en: 'Inside an LXC container', fr: 'Dans un conteneur LXC' },
    groupLxcBody: {
        en: 'Run these inside a container, not on the host: Proxmox VE itself is left untouched.',
        fr: 'À lancer dans un conteneur, pas sur l’hôte : Proxmox VE lui-même n’est pas touché.',
    },
    groupLxcRail: 'LXC',
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
    demoTab: { en: 'Demo', fr: 'Démo' },
    menuTab: { en: 'Script menu', fr: 'Menu du script' },
    demoZoom: { en: 'Click to enlarge', fr: 'Cliquer pour agrandir' },
    demoClose: { en: 'Close', fr: 'Fermer' },
    demoNote: { en: 'The real Proxmox VE interface, with demo data', fr: 'La vraie interface Proxmox VE, avec des données de démonstration' },
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
