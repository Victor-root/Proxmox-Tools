#!/usr/bin/env bash
set -euo pipefail
umask 077

# Installs Nginx in a Debian or Ubuntu container and manages it as a reverse
# proxy: sites, certificates, logs and backups.

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
SCRIPT_URL="https://raw.githubusercontent.com/Victor-root/Proxmox-Tools/main/scripts/lxc-nginx-reverse-proxy.sh"
APP_NAME="NGINX Reverse Proxy Manager"
MANAGED_MARKER="Managed by Proxmox-Tools lxc-nginx-reverse-proxy.sh"

NGINX_DIR="/etc/nginx"
SITES_AVAILABLE="${NGINX_DIR}/sites-available"
SITES_ENABLED="${NGINX_DIR}/sites-enabled"
SNIPPETS_DIR="${NGINX_DIR}/snippets"
CONF_D="${NGINX_DIR}/conf.d"
NGINX_CONF="${NGINX_DIR}/nginx.conf"
TLS_COMMON="${SNIPPETS_DIR}/tls-common.conf"
PROXY_SNIPPET="${SNIPPETS_DIR}/proxy-common.conf"
WEBSOCKET_MAP="${CONF_D}/00-websocket-map.conf"
DEFAULT_VHOST="${SITES_AVAILABLE}/00-default"
ACME_ROOT="/var/www/acme"
LE_LIVE="/etc/letsencrypt/live"
LE_DEPLOY_HOOK="/etc/letsencrypt/renewal-hooks/deploy/reload-nginx"
SYSTEM_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
BACKUP_ROOT="/root/nginx-manager-backups"
COMMAND_PATH="/usr/local/sbin/nginx-proxy"

# ── Language ──────────────────────────────────────────────────────────────────

detect_lang() {
    local raw="${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}"
    raw="${raw,,}"
    case "$raw" in
        fr*) APP_LANG="fr" ;;
        *)   APP_LANG="en" ;;
    esac
}

APP_LANG="en"
detect_lang

tr_msg() {
    local key="$1"
    case "${APP_LANG}:${key}" in
        fr:repo_hint) echo "Installation de Nginx et gestion de ses reverse proxies" ;;
        en:repo_hint) echo "Nginx install and reverse proxy management" ;;

        fr:detected_language) echo "Langue détectée" ;;
        en:detected_language) echo "Detected language" ;;

        fr:lang_fr) echo "Français" ;;
        en:lang_fr) echo "French" ;;

        fr:lang_en) echo "Anglais" ;;
        en:lang_en) echo "English" ;;

        fr:need_root) echo "Ce script doit être lancé en root." ;;
        en:need_root) echo "This script must be run as root." ;;

        fr:dir_missing) echo "Répertoire Nginx introuvable" ;;
        en:dir_missing) echo "Nginx directory not found" ;;

        fr:press_enter) echo "Appuyez sur Entrée pour continuer..." ;;
        en:press_enter) echo "Press Enter to continue..." ;;

        fr:invalid_choice) echo "Choix invalide." ;;
        en:invalid_choice) echo "Invalid choice." ;;

        fr:cancelled) echo "Opération annulée." ;;
        en:cancelled) echo "Operation cancelled." ;;

        fr:bye) echo "À bientôt." ;;
        en:bye) echo "Bye." ;;

        fr:choose_option) echo "Choisissez une option" ;;
        en:choose_option) echo "Choose an option" ;;

        fr:yes_hint) echo "Entrée=oui / non" ;;
        en:yes_hint) echo "Enter=yes / no" ;;

        fr:no_hint) echo "oui / Entrée=non" ;;
        en:no_hint) echo "yes / Enter=no" ;;

        fr:menu_sites) echo "Gérer les sites / reverse proxies" ;;
        en:menu_sites) echo "Manage sites / reverse proxies" ;;

        fr:menu_add) echo "Ajouter un reverse proxy avec l'assistant" ;;
        en:menu_add) echo "Add a reverse proxy with the wizard" ;;

        fr:menu_configs) echo "Fichiers importants et snippets" ;;
        en:menu_configs) echo "Important files and snippets" ;;

        fr:menu_check) echo "Tester la configuration Nginx" ;;
        en:menu_check) echo "Test the Nginx configuration" ;;

        fr:menu_reload) echo "Recharger Nginx" ;;
        en:menu_reload) echo "Reload Nginx" ;;

        fr:menu_logs) echo "Consulter les logs" ;;
        en:menu_logs) echo "View logs" ;;

        fr:menu_backup) echo "Sauvegardes Nginx" ;;
        en:menu_backup) echo "Nginx backups" ;;

        fr:menu_quit) echo "Quitter" ;;
        en:menu_quit) echo "Quit" ;;

        fr:status_title) echo "État du reverse proxy" ;;
        en:status_title) echo "Reverse proxy status" ;;

        fr:status_service) echo "Service nginx" ;;
        en:status_service) echo "nginx service" ;;

        fr:status_config) echo "Configuration" ;;
        en:status_config) echo "Configuration" ;;

        fr:status_sites) echo "Sites disponibles / activés" ;;
        en:status_sites) echo "Available / enabled sites" ;;

        fr:status_cert) echo "Prochain certificat à expirer" ;;
        en:status_cert) echo "Next certificate to expire" ;;

        fr:status_backups) echo "Sauvegardes" ;;
        en:status_backups) echo "Backups" ;;

        fr:status_active) echo "actif" ;;
        en:status_active) echo "active" ;;

        fr:status_inactive) echo "inactif" ;;
        en:status_inactive) echo "inactive" ;;

        fr:status_valid) echo "valide" ;;
        en:status_valid) echo "valid" ;;

        fr:status_invalid) echo "INVALIDE" ;;
        en:status_invalid) echo "INVALID" ;;

        fr:status_missing) echo "absent" ;;
        en:status_missing) echo "missing" ;;

        fr:cert_days) echo "jours restants" ;;
        en:cert_days) echo "days left" ;;

        fr:sites_title) echo "Sites Nginx" ;;
        en:sites_title) echo "Nginx sites" ;;

        fr:sites_none) echo "Aucun fichier trouvé dans sites-available." ;;
        en:sites_none) echo "No files found in sites-available." ;;

        fr:site_enabled) echo "activé" ;;
        en:site_enabled) echo "enabled" ;;

        fr:site_disabled) echo "désactivé" ;;
        en:site_disabled) echo "disabled" ;;

        fr:site_select) echo "Numéro du site" ;;
        en:site_select) echo "Site number" ;;

        fr:site_back) echo "Retour" ;;
        en:site_back) echo "Back" ;;

        fr:site_summary) echo "Résumé du site" ;;
        en:site_summary) echo "Site summary" ;;

        fr:site_view) echo "Afficher le fichier" ;;
        en:site_view) echo "View file" ;;

        fr:site_edit) echo "Modifier avec l'éditeur" ;;
        en:site_edit) echo "Edit with editor" ;;

        fr:site_enable) echo "Activer le site" ;;
        en:site_enable) echo "Enable site" ;;

        fr:site_disable) echo "Désactiver le site" ;;
        en:site_disable) echo "Disable site" ;;

        fr:site_test_backend) echo "Tester le backend détecté" ;;
        en:site_test_backend) echo "Test detected backend" ;;

        fr:site_change_backend) echo "Modifier le backend (IP / nom / port)" ;;
        en:site_change_backend) echo "Change backend (IP / hostname / port)" ;;

        fr:backend_change_title) echo "Modifier la destination du backend" ;;
        en:backend_change_title) echo "Change backend destination" ;;

        fr:backend_targets) echo "Backends détectés dans ce site" ;;
        en:backend_targets) echo "Backends detected in this site" ;;

        fr:backend_select) echo "Numéro du backend à modifier" ;;
        en:backend_select) echo "Backend number to change" ;;

        fr:backend_current_host) echo "Adresse actuelle" ;;
        en:backend_current_host) echo "Current address" ;;

        fr:backend_current_port) echo "Port actuel" ;;
        en:backend_current_port) echo "Current port" ;;

        fr:backend_new_host) echo "Nouvelle IP ou nouveau nom (Entrée = garder)" ;;
        en:backend_new_host) echo "New IP or hostname (Enter = keep)" ;;

        fr:backend_new_port) echo "Nouveau port (Entrée = garder)" ;;
        en:backend_new_port) echo "New port (Enter = keep)" ;;

        fr:backend_new_target) echo "Nouvelle cible" ;;
        en:backend_new_target) echo "New target" ;;

        fr:backend_apply_all) echo "Toutes les directives proxy_pass utilisant cette même destination (protocole + adresse + port) seront mises à jour, en conservant leurs chemins." ;;
        en:backend_apply_all) echo "Every proxy_pass using the same destination (scheme + address + port) will be updated while preserving paths." ;;

        fr:backend_change_confirm) echo "Appliquer ce changement ?" ;;
        en:backend_change_confirm) echo "Apply this change?" ;;

        fr:backend_changed) echo "Destination du backend mise à jour." ;;
        en:backend_changed) echo "Backend destination updated." ;;

        fr:backend_same) echo "L'adresse et le port sont déjà identiques, rien à modifier." ;;
        en:backend_same) echo "Address and port are already identical; nothing to change." ;;

        fr:backend_target_unsupported) echo "Cette cible proxy_pass ne peut pas être modifiée automatiquement. Utilisez l'éditeur." ;;
        en:backend_target_unsupported) echo "This proxy_pass target cannot be changed automatically. Use the editor." ;;

        fr:backend_named_warning) echo "La cible actuelle ressemble à un nom DNS ou à un upstream Nginx, pas à une IP directe. Le remplacement reste possible, vérifiez simplement que c'est bien voulu." ;;
        en:backend_named_warning) echo "The current target looks like a DNS name or Nginx upstream, not a direct IP. Replacement is still possible, but make sure this is intended." ;;

        fr:site_delete) echo "Supprimer / archiver le site" ;;
        en:site_delete) echo "Delete / archive site" ;;

        fr:site_filename) echo "Fichier" ;;
        en:site_filename) echo "File" ;;

        fr:site_server_name) echo "Nom(s) DNS" ;;
        en:site_server_name) echo "DNS name(s)" ;;

        fr:site_proxy_pass) echo "Backend(s)" ;;
        en:site_proxy_pass) echo "Backend(s)" ;;

        fr:site_no_backend) echo "Aucun proxy_pass détecté dans ce fichier." ;;
        en:site_no_backend) echo "No proxy_pass detected in this file." ;;

        fr:file_not_found) echo "Fichier introuvable" ;;
        en:file_not_found) echo "File not found" ;;

        fr:backup_created) echo "Sauvegarde créée" ;;
        en:backup_created) echo "Backup created" ;;

        fr:editing) echo "Ouverture de" ;;
        en:editing) echo "Opening" ;;

        fr:editor_missing) echo "Aucun éditeur trouvé (nano, vim ou vi)." ;;
        en:editor_missing) echo "No editor found (nano, vim or vi)." ;;

        fr:test_ok) echo "Configuration Nginx valide." ;;
        en:test_ok) echo "Nginx configuration is valid." ;;

        fr:test_fail) echo "La configuration Nginx est invalide." ;;
        en:test_fail) echo "The Nginx configuration is invalid." ;;

        fr:restore_question) echo "Restaurer automatiquement la sauvegarde précédente ?" ;;
        en:restore_question) echo "Automatically restore the previous backup?" ;;

        fr:restored) echo "Ancienne version restaurée." ;;
        en:restored) echo "Previous version restored." ;;

        fr:reload_question) echo "Recharger Nginx maintenant ?" ;;
        en:reload_question) echo "Reload Nginx now?" ;;

        fr:reload_ok) echo "Nginx rechargé." ;;
        en:reload_ok) echo "Nginx reloaded." ;;

        fr:reload_fail) echo "Échec du rechargement de Nginx." ;;
        en:reload_fail) echo "Failed to reload Nginx." ;;

        fr:enable_ok) echo "Site activé." ;;
        en:enable_ok) echo "Site enabled." ;;

        fr:disable_ok) echo "Site désactivé." ;;
        en:disable_ok) echo "Site disabled." ;;

        fr:already_enabled) echo "Le site est déjà activé." ;;
        en:already_enabled) echo "The site is already enabled." ;;

        fr:already_disabled) echo "Le site est déjà désactivé." ;;
        en:already_disabled) echo "The site is already disabled." ;;

        fr:wizard_title) echo "Assistant nouveau reverse proxy" ;;
        en:wizard_title) echo "New reverse proxy wizard" ;;

        fr:wizard_intro1) echo "L'assistant crée un site HTTPS avec sa redirection depuis HTTP." ;;
        en:wizard_intro1) echo "The wizard creates an HTTPS site with its redirect from HTTP." ;;

        fr:wizard_intro2) echo "Une sauvegarde est faite avant toute modification et nginx -t est exécuté avant reload." ;;
        en:wizard_intro2) echo "A backup is made before changes and nginx -t runs before reload." ;;

        fr:wizard_intro3) echo "Le DNS du nom choisi doit pointer vers ce conteneur, et les ports 80 et 443 doivent l'atteindre." ;;
        en:wizard_intro3) echo "The DNS of the chosen name has to point to this container, and ports 80 and 443 have to reach it." ;;

        fr:prompt_fqdn) echo "Nom DNS complet, ex. app.example.com" ;;
        en:prompt_fqdn) echo "Full DNS name, e.g. app.example.com" ;;

        fr:prompt_backend_host) echo "IP ou nom du backend, ex. 192.168.1.50" ;;
        en:prompt_backend_host) echo "Backend IP or hostname, e.g. 192.168.1.50" ;;

        fr:prompt_backend_port) echo "Port du backend" ;;
        en:prompt_backend_port) echo "Backend port" ;;

        fr:prompt_backend_scheme) echo "Protocole backend : 1=http, 2=https" ;;
        en:prompt_backend_scheme) echo "Backend protocol: 1=http, 2=https" ;;

        fr:prompt_enable) echo "Activer ce site après création ?" ;;
        en:prompt_enable) echo "Enable this site after creation?" ;;

        fr:invalid_fqdn) echo "Nom DNS invalide." ;;
        en:invalid_fqdn) echo "Invalid DNS name." ;;

        fr:invalid_host) echo "Backend invalide." ;;
        en:invalid_host) echo "Invalid backend." ;;

        fr:invalid_port) echo "Port invalide." ;;
        en:invalid_port) echo "Invalid port." ;;

        fr:already_exists) echo "Un fichier existe déjà pour ce site" ;;
        en:already_exists) echo "A file already exists for this site" ;;

        fr:preview_title) echo "Aperçu du fichier qui sera créé" ;;
        en:preview_title) echo "Preview of the file to be created" ;;

        fr:create_question) echo "Créer ce vhost ?" ;;
        en:create_question) echo "Create this vhost?" ;;

        fr:created) echo "Vhost créé" ;;
        en:created) echo "Vhost created" ;;

        fr:create_rolled_back) echo "La création a été annulée car nginx -t a échoué. Le fichier a été retiré." ;;
        en:create_rolled_back) echo "Creation was rolled back because nginx -t failed. The file was removed." ;;

        fr:config_title) echo "Fichiers importants" ;;
        en:config_title) echo "Important files" ;;

        fr:config_nginx) echo "Configuration principale nginx.conf" ;;
        en:config_nginx) echo "Main nginx.conf configuration" ;;

        fr:config_default) echo "Vhost par défaut" ;;
        en:config_default) echo "Default vhost" ;;

        fr:config_tls) echo "Réglages TLS communs" ;;
        en:config_tls) echo "Common TLS settings" ;;

        fr:config_proxy) echo "Snippet proxy commun" ;;
        en:config_proxy) echo "Common proxy snippet" ;;

        fr:config_ws) echo "Map WebSocket" ;;
        en:config_ws) echo "WebSocket map" ;;

        fr:config_other_snippet) echo "Choisir un autre snippet" ;;
        en:config_other_snippet) echo "Choose another snippet" ;;

        fr:config_other_conf) echo "Choisir un fichier dans conf.d" ;;
        en:config_other_conf) echo "Choose a file from conf.d" ;;

        fr:config_back) echo "Retour" ;;
        en:config_back) echo "Back" ;;

        fr:not_detected) echo "non détecté" ;;
        en:not_detected) echo "not detected" ;;

        fr:logs_title) echo "Logs Nginx" ;;
        en:logs_title) echo "Nginx logs" ;;

        fr:logs_error) echo "Dernières lignes error.log" ;;
        en:logs_error) echo "Last error.log lines" ;;

        fr:logs_access) echo "Dernières lignes access.log" ;;
        en:logs_access) echo "Last access.log lines" ;;

        fr:logs_journal) echo "Journal systemd nginx" ;;
        en:logs_journal) echo "nginx systemd journal" ;;

        fr:logs_choose) echo "Choisir un autre fichier de log" ;;
        en:logs_choose) echo "Choose another log file" ;;

        fr:logs_back) echo "Retour" ;;
        en:logs_back) echo "Back" ;;

        fr:backup_title) echo "Sauvegardes Nginx" ;;
        en:backup_title) echo "Nginx backups" ;;

        fr:backup_full) echo "Créer une sauvegarde complète de /etc/nginx" ;;
        en:backup_full) echo "Create a full /etc/nginx backup" ;;

        fr:backup_list) echo "Lister les sauvegardes complètes" ;;
        en:backup_list) echo "List full backups" ;;

        fr:backup_restore) echo "Restaurer une sauvegarde complète" ;;
        en:backup_restore) echo "Restore a full backup" ;;

        fr:backup_back) echo "Retour" ;;
        en:backup_back) echo "Back" ;;

        fr:backup_full_ok) echo "Sauvegarde complète créée" ;;
        en:backup_full_ok) echo "Full backup created" ;;

        fr:backup_none) echo "Aucune sauvegarde complète trouvée." ;;
        en:backup_none) echo "No full backup found." ;;

        fr:restore_warning) echo "La restauration remplace /etc/nginx. Une sauvegarde de sécurité de l'état actuel sera créée avant." ;;
        en:restore_warning) echo "Restore replaces /etc/nginx. A safety backup of the current state will be created first." ;;

        fr:restore_failed) echo "La sauvegarde restaurée est invalide. Retour automatique à l'état précédent." ;;
        en:restore_failed) echo "The restored backup is invalid. Automatically rolling back to the previous state." ;;

        fr:restore_ok) echo "Sauvegarde restaurée et Nginx rechargé." ;;
        en:restore_ok) echo "Backup restored and Nginx reloaded." ;;

        fr:delete_warning) echo "Le site sera retiré de sites-enabled et archivé dans les sauvegardes." ;;
        en:delete_warning) echo "The site will be removed from sites-enabled and archived in backups." ;;

        fr:delete_confirm) echo "Tapez exactement le nom du fichier pour confirmer" ;;
        en:delete_confirm) echo "Type the exact filename to confirm" ;;

        fr:delete_ok) echo "Site archivé" ;;
        en:delete_ok) echo "Site archived" ;;

        fr:backend_testing) echo "Test du backend" ;;
        en:backend_testing) echo "Testing backend" ;;

        fr:backend_ok) echo "Backend joignable." ;;
        en:backend_ok) echo "Backend reachable." ;;

        fr:backend_fail) echo "Le backend n'a pas répondu correctement. Voir la sortie ci-dessous." ;;
        en:backend_fail) echo "Backend did not respond successfully. See output below." ;;

        fr:command_installed) echo "Commande installée" ;;
        en:command_installed) echo "Command installed" ;;

        fr:command_install_fail) echo "Impossible de télécharger la commande." ;;
        en:command_install_fail) echo "Could not download the command." ;;

        fr:type_yes) echo "Tapez yes pour confirmer" ;;
        en:type_yes) echo "Type yes to confirm" ;;

        fr:label_host) echo "Hôte" ;;
        en:label_host) echo "Host" ;;

        fr:site_state) echo "État" ;;
        en:site_state) echo "State" ;;

        fr:unsupported_system) echo "Ce script a besoin de Debian ou Ubuntu avec apt et systemd." ;;
        en:unsupported_system) echo "This script needs Debian or Ubuntu with apt and systemd." ;;

        fr:install_title) echo "Installation de Nginx" ;;
        en:install_title) echo "Nginx install" ;;

        fr:install_body_1) echo "Nginx n'est pas encore installé dans ce conteneur." ;;
        en:install_body_1) echo "Nginx is not installed in this container yet." ;;

        fr:install_body_2) echo "Paquets installés : nginx, openssl, curl, ca-certificates." ;;
        en:install_body_2) echo "Packages installed: nginx, openssl, curl, ca-certificates." ;;

        fr:install_failed) echo "L'installation a échoué. Voir la sortie d'apt ci-dessus." ;;
        en:install_failed) echo "The install failed. See the apt output above." ;;

        fr:install_ok) echo "Nginx est installé." ;;
        en:install_ok) echo "Nginx is installed." ;;

        fr:base_title) echo "Configuration de base" ;;
        en:base_title) echo "Base configuration" ;;

        fr:base_body_1) echo "Crée les fichiers communs à tous les sites, uniquement ceux qui manquent : un fichier existant n'est jamais remplacé." ;;
        en:base_body_1) echo "Creates the files every site shares, only the missing ones: an existing file is never replaced." ;;

        fr:base_body_2) echo "Si la page par défaut de Nginx est intacte, elle est désactivée, et un vhost par défaut refuse les noms inconnus." ;;
        en:base_body_2) echo "If the stock Nginx page is untouched it is disabled, and a default vhost refuses unknown names." ;;

        fr:base_ok) echo "Configuration de base prête." ;;
        en:base_ok) echo "Base configuration ready." ;;

        fr:base_rolled_back) echo "nginx -t a échoué : les fichiers créés ont été retirés." ;;
        en:base_rolled_back) echo "nginx -t failed: the files created were removed." ;;

        fr:base_needed) echo "Les sites ont besoin de la configuration de base." ;;
        en:base_needed) echo "Sites need the base configuration." ;;

        fr:cert_title) echo "Certificat HTTPS" ;;
        en:cert_title) echo "HTTPS certificate" ;;

        fr:cert_le) echo "Let's Encrypt pour ce nom (gratuit, renouvelé automatiquement)" ;;
        en:cert_le) echo "Let's Encrypt for this name (free, renewed automatically)" ;;

        fr:cert_own) echo "Mon propre certificat (chemins à indiquer)" ;;
        en:cert_own) echo "My own certificate (paths to give)" ;;

        fr:cert_snippet) echo "Déjà configuré" ;;
        en:cert_snippet) echo "Already set up" ;;

        fr:prompt_cert_path) echo "Chemin du certificat complet (fullchain)" ;;
        en:prompt_cert_path) echo "Path of the full certificate (fullchain)" ;;

        fr:prompt_key_path) echo "Chemin de la clé privée" ;;
        en:prompt_key_path) echo "Path of the private key" ;;

        fr:cert_mismatch) echo "La clé privée ne correspond pas à ce certificat." ;;
        en:cert_mismatch) echo "The private key does not match this certificate." ;;

        fr:le_terms) echo "En continuant, vous acceptez les conditions d'utilisation de Let's Encrypt." ;;
        en:le_terms) echo "By continuing you accept the Let's Encrypt terms of service." ;;

        fr:le_needs) echo "Le DNS de ce nom doit déjà pointer ici et le port 80 doit être joignable depuis Internet." ;;
        en:le_needs) echo "The DNS of this name already has to point here, and port 80 has to be reachable from the Internet." ;;

        fr:prompt_email) echo "E-mail pour les alertes d'expiration (Entrée = aucun)" ;;
        en:prompt_email) echo "E-mail for expiry alerts (Enter = none)" ;;

        fr:invalid_email) echo "E-mail invalide." ;;
        en:invalid_email) echo "Invalid e-mail." ;;

        fr:certbot_installing) echo "Installation de certbot..." ;;
        en:certbot_installing) echo "Installing certbot..." ;;

        fr:le_requesting) echo "Demande du certificat à Let's Encrypt..." ;;
        en:le_requesting) echo "Requesting the certificate from Let's Encrypt..." ;;

        fr:le_failed) echo "Let's Encrypt a refusé la demande : le site a été retiré. Vérifiez le DNS et le port 80." ;;
        en:le_failed) echo "Let's Encrypt refused the request: the site was removed. Check the DNS and port 80." ;;

        fr:prompt_backend_verify) echo "Vérifier le certificat du backend ? Il doit venir d'une autorité reconnue et correspondre à l'adresse. Répondez non s'il est autosigné" ;;
        en:prompt_backend_verify) echo "Verify the backend certificate? It has to come from a known authority and match the address. Answer no if it is self-signed" ;;

        fr:site_regular_file) echo "Ce fichier n'est pas un lien symbolique, il ne sera pas retiré automatiquement" ;;
        en:site_regular_file) echo "This is a regular file, not a symbolic link, it will not be removed automatically" ;;

        fr:delete_le_question) echo "Supprimer aussi son certificat Let's Encrypt ?" ;;
        en:delete_le_question) echo "Also delete its Let's Encrypt certificate?" ;;

        fr:curl_missing) echo "curl et wget sont absents." ;;
        en:curl_missing) echo "curl and wget are both missing." ;;

        fr:restore_bad_archive) echo "Cette archive est illisible ou ne contient pas que la configuration Nginx. Rien n'a été modifié." ;;
        en:restore_bad_archive) echo "This archive is unreadable or holds more than the Nginx configuration. Nothing was changed." ;;

        fr:menu_install_cmd) echo "Installer la commande nginx-proxy" ;;
        en:menu_install_cmd) echo "Install the nginx-proxy command" ;;

        fr:command_run) echo "Lancez" ;;
        en:command_run) echo "Run" ;;

        fr:command_already) echo "Ce script est déjà la commande installée." ;;
        en:command_already) echo "This script already is the installed command." ;;

        fr:menu_uninstall) echo "Désinstaller Nginx" ;;
        en:menu_uninstall) echo "Uninstall Nginx" ;;

        fr:uninstall_body_1) echo "Retire Nginx, sa configuration et la commande nginx-proxy, après une sauvegarde complète." ;;
        en:uninstall_body_1) echo "Removes Nginx, its configuration and the nginx-proxy command, after a full backup." ;;

        fr:uninstall_body_2) echo "Les sauvegardes restent en place, ainsi que certbot et ses certificats." ;;
        en:uninstall_body_2) echo "The backups stay in place, and so do certbot and its certificates." ;;

        fr:uninstall_ok) echo "Nginx est désinstallé." ;;
        en:uninstall_ok) echo "Nginx is uninstalled." ;;

        *) echo "$key" ;;
    esac
}

# ── Colors / visual engine, dedicated NGINX green theme ──────────────────────

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    RESET='\033[0m'
    BOLD='\033[1m'

    # NGINX-inspired green palette. Red and amber remain semantic warning/error colors.
    NGX_GREEN='\033[38;5;34m'
    NGX_GREEN_DARK='\033[38;5;28m'
    NGX_GREEN_SOFT='\033[38;5;40m'
    NGX_RED='\033[38;5;124m'
    NGX_AMBER='\033[38;5;214m'
    NGX_CYAN='\033[38;5;73m'
    NGX_GREY='\033[38;5;244m'
else
    RESET=''; BOLD=''
    NGX_GREEN=''; NGX_GREEN_DARK=''; NGX_GREEN_SOFT=''
    NGX_RED=''; NGX_AMBER=''; NGX_CYAN=''; NGX_GREY=''
fi

term_width() {
    local cols
    cols="$(tput cols 2>/dev/null || echo 80)"
    [[ -z "$cols" || "$cols" -lt 50 ]] && cols=80
    [[ "$cols" -gt 100 ]] && cols=100
    echo "$cols"
}

hr() {
    local cols line
    cols="$(term_width)"
    printf -v line '%*s' "$cols" ''
    printf '%b%s%b\n' "$NGX_GREEN_DARK" "${line// /─}" "$RESET"
}

panel() {
    local color="$1" title="$2"
    shift 2
    echo
    printf '%b┌%b %b%b%s%b\n' "$color" "$RESET" "$BOLD" "$color" "$title" "$RESET"
    while (($#)); do
        printf '%b│%b %b\n' "$color" "$RESET" "$1"
        shift
    done
    printf '%b└%b\n' "$color" "$RESET"
}

say_info() { printf '%b›%b %b\n' "$NGX_GREEN_SOFT" "$RESET" "$*"; }
say_ok()   { printf '%b✓%b %b\n' "$NGX_GREEN_SOFT" "$RESET" "$*"; }
say_warn() { printf '%b⚠%b %b\n' "$NGX_AMBER" "$RESET" "$*"; }
say_err()  { printf '%b✗%b %b\n' "$NGX_RED" "$RESET" "$*" >&2; }

banner() {
    clear || true
    echo
    printf '%b%s%b\n' "$NGX_GREEN" '███╗   ██╗ ██████╗ ██╗███╗   ██╗██╗  ██╗' "$RESET"
    printf '%b%s%b\n' "$NGX_GREEN" '████╗  ██║██╔════╝ ██║████╗  ██║╚██╗██╔╝' "$RESET"
    printf '%b%s%b\n' "$NGX_GREEN" '██╔██╗ ██║██║  ███╗██║██╔██╗ ██║ ╚███╔╝ ' "$RESET"
    printf '%b%s%b\n' "$NGX_GREEN" '██║╚██╗██║██║   ██║██║██║╚██╗██║ ██╔██╗ ' "$RESET"
    printf '%b%s%b\n' "$NGX_GREEN" '██║ ╚████║╚██████╔╝██║██║ ╚████║██╔╝ ██╗' "$RESET"
    printf '%b%s%b\n' "$NGX_GREEN" '╚═╝  ╚═══╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝' "$RESET"
    echo
    printf '  %b%s%b %b· by Victor-root%b\n' "${BOLD}${NGX_GREEN_SOFT}" "$APP_NAME" "$RESET" "$NGX_GREY" "$RESET"
    hr
}

show_banner() {
    banner
    local lang_label
    [[ "$APP_LANG" == "fr" ]] && lang_label="$(tr_msg lang_fr)" || lang_label="$(tr_msg lang_en)"
    panel "$NGX_GREEN_DARK" "$(tr_msg repo_hint)" \
        "$(tr_msg label_host): ${BOLD}$(hostname)${RESET}" \
        "Nginx: ${BOLD}${NGINX_DIR}${RESET}" \
        "$(tr_msg detected_language): ${BOLD}${lang_label}${RESET}"
    echo
}

pause() {
    echo
    # no more input, a menu would otherwise loop on its invalid choice forever
    read -r -p "$(tr_msg press_enter)" _ || exit 0
}

confirm_default_yes() {
    local label="$1" value
    printf '%b?%b %b%s%b %b[%s]%b : ' "$NGX_AMBER" "$RESET" "$BOLD" "$label" "$RESET" "$NGX_GREY" "$(tr_msg yes_hint)" "$RESET"
    IFS= read -r value || true
    value="${value:-yes}"
    value="${value,,}"
    [[ "$value" == "y" || "$value" == "yes" || "$value" == "o" || "$value" == "oui" ]]
}

confirm_default_no() {
    local label="$1" value
    printf '%b?%b %b%s%b %b[%s]%b : ' "$NGX_AMBER" "$RESET" "$BOLD" "$label" "$RESET" "$NGX_GREY" "$(tr_msg no_hint)" "$RESET"
    IFS= read -r value || true
    value="${value,,}"
    [[ "$value" == "y" || "$value" == "yes" || "$value" == "o" || "$value" == "oui" ]]
}

confirm_yes() {
    local answer
    echo
    printf '%b?%b %b%s%b : ' "$NGX_AMBER" "$RESET" "$BOLD" "$(tr_msg type_yes)" "$RESET"
    IFS= read -r answer || true
    [[ "$answer" == "yes" ]]
}

prompt_free() {
    local label="$1" default="${2:-}" value
    if [[ -n "$default" ]]; then
        printf '%b?%b %b%s%b %b[%s]%b : ' "$NGX_GREEN_SOFT" "$RESET" "$BOLD" "$label" "$RESET" "$NGX_GREY" "$default" "$RESET" >&2
    else
        printf '%b?%b %b%s%b : ' "$NGX_GREEN_SOFT" "$RESET" "$BOLD" "$label" "$RESET" >&2
    fi
    IFS= read -r value || true
    printf '%s' "${value:-$default}"
}

# ── Requirements / helpers ───────────────────────────────────────────────────

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        say_err "$(tr_msg need_root)"
        exit 1
    fi
}

require_system() {
    if ! command -v apt-get >/dev/null 2>&1 || ! command -v systemctl >/dev/null 2>&1; then
        say_err "$(tr_msg unsupported_system)"
        exit 1
    fi
}

install_nginx() {
    panel "$NGX_GREEN" "$(tr_msg install_title)" "$(tr_msg install_body_1)" "$(tr_msg install_body_2)"
    if ! confirm_yes; then
        say_info "$(tr_msg cancelled)"
        return 1
    fi
    if ! { DEBIAN_FRONTEND=noninteractive apt-get update &&
           DEBIAN_FRONTEND=noninteractive apt-get install -y nginx openssl curl ca-certificates; }; then
        say_err "$(tr_msg install_failed)"
        return 1
    fi
    say_ok "$(tr_msg install_ok)"
}

ensure_nginx() {
    if ! command -v nginx >/dev/null 2>&1; then
        install_nginx || exit 1
        setup_base || true
        pause
    fi
    [[ -d "$NGINX_DIR" ]] || { say_err "$(tr_msg dir_missing): $NGINX_DIR"; exit 1; }
    mkdir -p "$BACKUP_ROOT"
}

# Everything under /etc/nginx and the ACME directory is read by the unprivileged
# workers, the umask of the script would hide it from them.
write_public() {
    cat >"$1"
    chmod 0644 "$1"
}

safe_timestamp() { date '+%Y%m%d-%H%M%S'; }

count_files() {
    local dir="$1"
    [[ -d "$dir" ]] || { echo 0; return; }
    find "$dir" -maxdepth 1 -type f -printf '.' 2>/dev/null | wc -c
}

count_enabled_sites() {
    [[ -d "$SITES_ENABLED" ]] || { echo 0; return; }
    find "$SITES_ENABLED" -mindepth 1 -maxdepth 1 \( -type l -o -type f \) -printf '.' 2>/dev/null | wc -c
}

is_site_enabled() {
    local name="$1"
    [[ -e "$SITES_ENABLED/$name" || -L "$SITES_ENABLED/$name" ]]
}

find_default_vhost() {
    local p
    for p in "$SITES_AVAILABLE/00-default" "$SITES_AVAILABLE/00-default.conf" "$SITES_ENABLED/00-default" "$SITES_ENABLED/00-default.conf"; do
        [[ -e "$p" || -L "$p" ]] && { readlink -f "$p" 2>/dev/null || echo "$p"; return 0; }
    done
    p="$(find "$SITES_AVAILABLE" -maxdepth 1 -type f -iname '*default*' -print 2>/dev/null | sort | head -n1 || true)"
    [[ -n "$p" ]] && { echo "$p"; return 0; }
    return 1
}

# ── Base configuration ────────────────────────────────────────────────────────

tls_common_body() {
    cat <<'CONF'
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1d;
ssl_session_tickets off;
CONF
}

proxy_common_body() {
    cat <<'CONF'
proxy_http_version 1.1;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $host;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
CONF
}

websocket_map_body() {
    cat <<'CONF'
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}
CONF
}

# ssl_reject_handshake came with Nginx 1.19.4. On an older one unknown names
# are only refused on port 80.
default_vhost_body() {
    local version
    version="$(nginx -v 2>&1 | sed -n 's|^nginx version: nginx/\([0-9.]*\).*|\1|p')"
    echo "# ${MANAGED_MARKER}"
    echo
    echo "server {"
    echo "    listen 80 default_server;"
    echo "    listen [::]:80 default_server;"
    if [[ "$(printf '1.19.4\n%s\n' "$version" | sort -V | head -n1)" == "1.19.4" ]]; then
        echo "    listen 443 ssl default_server;"
        echo "    listen [::]:443 ssl default_server;"
        echo "    ssl_reject_handshake on;"
    fi
    echo "    server_name _;"
    echo "    return 444;"
    echo "}"
}

websocket_map_exists() {
    local conf
    conf="$(nginx -T 2>/dev/null || true)"
    [[ "$conf" =~ map[[:space:]]+[^{]*\$connection_upgrade ]]
}

base_is_ready() {
    [[ -f "$TLS_COMMON" && -f "$PROXY_SNIPPET" ]] && websocket_map_exists
}

stock_default_enabled() {
    local changes
    [[ -L "$SITES_ENABLED/default" ]] || return 1
    [[ "$(readlink -f "$SITES_ENABLED/default")" == "$SITES_AVAILABLE/default" ]] || return 1
    changes="$(dpkg -V nginx-common 2>/dev/null || true)"
    [[ "$changes" != *"sites-available/default"* ]]
}

has_default_server() {
    local conf
    conf="$(nginx -T 2>/dev/null | sed 's/#.*$//' || true)"
    grep -Eq '(^|[[:space:];{])listen[[:space:]][^;]*default_server' <<<"$conf"
}

setup_base() {
    local stock_was_on="no" f
    local -a created=()

    panel "$NGX_GREEN" "$(tr_msg base_title)" "$(tr_msg base_body_1)" "$(tr_msg base_body_2)"
    if ! confirm_yes; then
        say_info "$(tr_msg cancelled)"
        return 1
    fi

    install -d -m 0755 "$ACME_ROOT" "$SNIPPETS_DIR" "$CONF_D" "$SITES_AVAILABLE" "$SITES_ENABLED"

    if [[ ! -e "$TLS_COMMON" ]]; then
        tls_common_body | write_public "$TLS_COMMON"
        created+=("$TLS_COMMON")
    fi
    if ! websocket_map_exists; then
        websocket_map_body | write_public "$WEBSOCKET_MAP"
        created+=("$WEBSOCKET_MAP")
    fi
    if [[ ! -e "$PROXY_SNIPPET" ]]; then
        proxy_common_body | write_public "$PROXY_SNIPPET"
        created+=("$PROXY_SNIPPET")
    fi
    if stock_default_enabled; then
        rm -f -- "${SITES_ENABLED:?}/default"
        stock_was_on="yes"
    fi
    if ! has_default_server && [[ ! -e "$DEFAULT_VHOST" ]]; then
        default_vhost_body | write_public "$DEFAULT_VHOST"
        ln -s "$DEFAULT_VHOST" "$SITES_ENABLED/00-default"
        created+=("$DEFAULT_VHOST" "$SITES_ENABLED/00-default")
    fi

    if ! nginx_test; then
        for f in "${created[@]}"; do
            rm -f -- "${f:?}"
        done
        [[ "$stock_was_on" == "yes" ]] && ln -s "$SITES_AVAILABLE/default" "$SITES_ENABLED/default"
        say_err "$(tr_msg base_rolled_back)"
        return 1
    fi

    systemctl reload-or-restart nginx
    say_ok "$(tr_msg base_ok)"
}

choose_editor() {
    if [[ -n "${EDITOR:-}" ]] && command -v "${EDITOR%% *}" >/dev/null 2>&1; then
        printf '%s' "${EDITOR%% *}"
    elif command -v nano >/dev/null 2>&1; then
        printf '%s' nano
    elif command -v vim >/dev/null 2>&1; then
        printf '%s' vim
    elif command -v vi >/dev/null 2>&1; then
        printf '%s' vi
    else
        return 1
    fi
}

backup_file() {
    local file="$1" stamp dir dest
    [[ -e "$file" || -L "$file" ]] || return 1
    stamp="$(safe_timestamp)"
    dir="$BACKUP_ROOT/files/$stamp"
    mkdir -p "$dir"
    dest="$dir/$(basename "$file")"
    cp -aL -- "$file" "$dest"
    printf '%s' "$dest"
}

nginx_test() {
    local out rc=0
    out="$(mktemp)"
    if nginx -t >"$out" 2>&1; then
        say_ok "$(tr_msg test_ok)"
    else
        rc=$?
        say_err "$(tr_msg test_fail)"
        sed 's/^/  /' "$out" >&2
    fi
    rm -f "${out:?}"
    return "$rc"
}

reload_nginx() {
    if ! nginx_test; then
        return 1
    fi
    if systemctl reload-or-restart nginx; then
        say_ok "$(tr_msg reload_ok)"
        return 0
    fi
    say_err "$(tr_msg reload_fail)"
    return 1
}

edit_file_safe() {
    local file="$1" editor backup
    [[ -f "$file" ]] || { say_err "$(tr_msg file_not_found): $file"; return 1; }
    editor="$(choose_editor)" || { say_err "$(tr_msg editor_missing)"; return 1; }
    backup="$(backup_file "$file")"
    say_info "$(tr_msg backup_created): ${NGX_CYAN}${backup}${RESET}"
    say_info "$(tr_msg editing) ${NGX_CYAN}${file}${RESET}"
    "$editor" "$file"
    if nginx_test; then
        if confirm_default_yes "$(tr_msg reload_question)"; then
            systemctl reload-or-restart nginx && say_ok "$(tr_msg reload_ok)" || say_err "$(tr_msg reload_fail)"
        fi
        return 0
    fi
    if confirm_default_yes "$(tr_msg restore_question)"; then
        cp -a -- "$backup" "$file"
        say_ok "$(tr_msg restored)"
        nginx_test || true
    fi
    return 1
}

print_file() {
    local file="$1"
    [[ -f "$file" ]] || { say_err "$(tr_msg file_not_found): $file"; return 1; }
    echo
    if command -v less >/dev/null 2>&1 && [[ -t 1 ]]; then
        less -R "$file"
    else
        cat "$file"
    fi
}

valid_fqdn() {
    local x="$1"
    [[ "$x" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]
}

valid_backend_host() {
    local x="$1"
    [[ -n "$x" && "$x" != *[[:space:]/]* && "$x" =~ ^[A-Za-z0-9._:-]+$ ]]
}

valid_email() {
    [[ "$1" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]
}

bracket_ipv6() {
    if [[ "$1" == *:* && "$1" != \[* ]]; then
        printf '[%s]' "$1"
    else
        printf '%s' "$1"
    fi
}

valid_port() {
    local p="$1"
    [[ "$p" =~ ^[0-9]+$ ]] && ((p >= 1 && p <= 65535))
}

# ── Dashboard ─────────────────────────────────────────────────────────────────

# Every certificate the running configuration points at, so a certificate set
# up by hand counts as much as one made by this script.
cert_summary() {
    local conf path end epoch days best="" best_path=""
    local now
    if ! command -v openssl >/dev/null 2>&1; then
        tr_msg status_missing
        return
    fi
    now="$(date +%s)"
    conf="$(nginx -T 2>/dev/null || true)"
    while IFS= read -r path; do
        [[ -f "$path" ]] || continue
        end="$(openssl x509 -in "$path" -noout -enddate 2>/dev/null | cut -d= -f2- || true)"
        [[ -n "$end" ]] || continue
        epoch="$(date -d "$end" +%s 2>/dev/null || echo 0)"
        ((epoch > 0)) || continue
        days=$(((epoch - now) / 86400))
        if [[ -z "$best" ]] || ((days < best)); then
            best="$days"
            best_path="$path"
        fi
    done < <(printf '%s\n' "$conf" | awk '$1=="ssl_certificate" {gsub(/;/, "", $2); print $2}' | sort -u)
    if [[ -n "$best" ]]; then
        printf '%s %s (%s)' "$best" "$(tr_msg cert_days)" "$best_path"
    else
        tr_msg status_missing
    fi
}

show_status() {
    local service_state config_state sites_avail sites_enabled cert_state backups
    if systemctl is-active --quiet nginx 2>/dev/null; then
        service_state="${NGX_GREEN_SOFT}$(tr_msg status_active)${RESET}"
    else
        service_state="${NGX_RED}$(tr_msg status_inactive)${RESET}"
    fi
    if nginx -t >/dev/null 2>&1; then
        config_state="${NGX_GREEN_SOFT}$(tr_msg status_valid)${RESET}"
    else
        config_state="${NGX_RED}$(tr_msg status_invalid)${RESET}"
    fi
    sites_avail="$(count_files "$SITES_AVAILABLE")"
    sites_enabled="$(count_enabled_sites)"
    cert_state="$(cert_summary)"
    backups="$(find "$BACKUP_ROOT" -maxdepth 1 -type f -name 'nginx-full-*.tar.gz' 2>/dev/null | wc -l)"
    panel "$NGX_GREEN" "$(tr_msg status_title)" \
        "$(tr_msg status_service): ${BOLD}${service_state}${RESET}" \
        "$(tr_msg status_config): ${BOLD}${config_state}${RESET}" \
        "$(tr_msg status_sites): ${BOLD}${sites_avail} / ${sites_enabled}${RESET}" \
        "$(tr_msg status_cert): ${BOLD}${cert_state}${RESET}" \
        "$(tr_msg status_backups): ${BOLD}${backups}${RESET} (${BACKUP_ROOT})"
}

# ── Sites ─────────────────────────────────────────────────────────────────────

list_sites_array() {
    mapfile -t SITE_LIST < <(find "$SITES_AVAILABLE" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort)
}

site_summary() {
    local name="$1"
    local file="$SITES_AVAILABLE/$name" server_names proxy_passes state
    [[ -f "$file" ]] || { say_err "$(tr_msg file_not_found): $file"; return 1; }
    server_names="$(awk '$1=="server_name" {sub(/;/, "", $0); $1=""; sub(/^[[:space:]]+/, "", $0); print; exit}' "$file" 2>/dev/null || true)"
    proxy_passes="$(awk '$1=="proxy_pass" {gsub(/;/, "", $2); print $2}' "$file" 2>/dev/null | paste -sd ', ' - || true)"
    [[ -n "$server_names" ]] || server_names="$(tr_msg not_detected)"
    [[ -n "$proxy_passes" ]] || proxy_passes="$(tr_msg not_detected)"
    is_site_enabled "$name" && state="${NGX_GREEN_SOFT}$(tr_msg site_enabled)${RESET}" || state="${NGX_GREY}$(tr_msg site_disabled)${RESET}"
    panel "$NGX_GREEN_DARK" "$(tr_msg site_summary)" \
        "$(tr_msg site_filename): ${BOLD}${file}${RESET}" \
        "$(tr_msg site_state): ${BOLD}${state}${RESET}" \
        "$(tr_msg site_server_name): ${BOLD}${server_names}${RESET}" \
        "$(tr_msg site_proxy_pass): ${BOLD}${proxy_passes}${RESET}"
}

enable_site() {
    local name="$1"
    local target="$SITES_AVAILABLE/$name" link="$SITES_ENABLED/$name"
    [[ -f "$target" ]] || { say_err "$(tr_msg file_not_found): $target"; return 1; }
    mkdir -p "$SITES_ENABLED"
    if is_site_enabled "$name"; then
        say_info "$(tr_msg already_enabled)"
        return 0
    fi
    ln -s "$target" "$link"
    if ! nginx_test; then
        rm -f -- "${link:?}"
        nginx_test || true
        return 1
    fi
    say_ok "$(tr_msg enable_ok)"
    confirm_default_yes "$(tr_msg reload_question)" && systemctl reload-or-restart nginx && say_ok "$(tr_msg reload_ok)" || true
}

disable_site() {
    local name="$1"
    local link="$SITES_ENABLED/$name" saved_target=""
    if ! is_site_enabled "$name"; then
        say_info "$(tr_msg already_disabled)"
        return 0
    fi
    if [[ -L "$link" ]]; then
        saved_target="$(readlink "$link")"
        rm -f -- "${link:?}"
    elif [[ -f "$link" ]]; then
        say_warn "$(tr_msg site_regular_file): $link"
        return 1
    fi
    if ! nginx_test; then
        [[ -n "$saved_target" ]] && ln -s "$saved_target" "$link"
        nginx_test || true
        return 1
    fi
    say_ok "$(tr_msg disable_ok)"
    confirm_default_yes "$(tr_msg reload_question)" && systemctl reload-or-restart nginx && say_ok "$(tr_msg reload_ok)" || true
}

first_proxy_pass() {
    local file="$1"
    awk '$1=="proxy_pass" {gsub(/;/, "", $2); print $2; exit}' "$file" 2>/dev/null || true
}

list_proxy_pass_targets() {
    local file="$1"
    awk '
        {
            line=$0
            sub(/[[:space:]]*#.*/, "", line)
            n=split(line, a, /[[:space:]]+/)
            for (i=1; i<=n; i++) {
                if (a[i] == "proxy_pass" && i < n) {
                    target=a[i+1]
                    sub(/;$/, "", target)
                    if (target != "") print target
                }
            }
        }
    ' "$file" 2>/dev/null | awk '!seen[$0]++'
}

proxy_target_host() {
    local target="$1" rest authority host
    [[ "$target" == http://* || "$target" == https://* ]] || return 1
    [[ "$target" != *'$'* ]] || return 1

    rest="${target#*://}"
    authority="${rest%%/*}"
    [[ -n "$authority" && "$authority" != *'@'* ]] || return 1

    if [[ "$authority" == \[* ]]; then
        [[ "$authority" == *']'* ]] || return 1
        host="${authority#\[}"
        host="${host%%\]*}"
    else
        host="${authority%%:*}"
    fi
    [[ -n "$host" ]] || return 1
    printf '%s' "$host"
}

proxy_target_scheme() {
    local target="$1"
    [[ "$target" == http://* || "$target" == https://* ]] || return 1
    printf '%s' "${target%%://*}"
}

proxy_target_explicit_port() {
    local target="$1" rest authority after
    [[ "$target" == http://* || "$target" == https://* ]] || return 1
    [[ "$target" != *'$'* ]] || return 1

    rest="${target#*://}"
    authority="${rest%%/*}"

    if [[ "$authority" == \[* ]]; then
        [[ "$authority" == *']'* ]] || return 1
        after="${authority#*]}"
        if [[ "$after" == :* ]]; then
            printf '%s' "${after#:}"
            return 0
        fi
    elif [[ "$authority" == *:* ]]; then
        printf '%s' "${authority##*:}"
        return 0
    fi
    return 1
}

proxy_target_port() {
    local target="$1" scheme port
    port="$(proxy_target_explicit_port "$target" 2>/dev/null || true)"
    if [[ -n "$port" ]]; then
        printf '%s' "$port"
        return 0
    fi
    scheme="$(proxy_target_scheme "$target")" || return 1
    case "$scheme" in
        http) printf '80' ;;
        https) printf '443' ;;
        *) return 1 ;;
    esac
}

proxy_target_with_host_port() {
    local target="$1" new_host="$2" new_port="$3"
    local scheme rest authority suffix="" shown_host default_port old_explicit="" portpart=""

    [[ "$target" == http://* || "$target" == https://* ]] || return 1
    [[ "$target" != *'$'* ]] || return 1
    valid_port "$new_port" || return 1

    scheme="${target%%://*}"
    rest="${target#*://}"
    if [[ "$rest" == */* ]]; then
        authority="${rest%%/*}"
        suffix="/${rest#*/}"
    else
        authority="$rest"
    fi

    old_explicit="$(proxy_target_explicit_port "$target" 2>/dev/null || true)"
    case "$scheme" in
        http) default_port=80 ;;
        https) default_port=443 ;;
        *) return 1 ;;
    esac

    shown_host="$(bracket_ipv6 "$new_host")"

    # Keep an implicit default port implicit when nothing changed. Otherwise,
    # write the chosen port explicitly so future test-service changes are clear.
    if [[ -n "$old_explicit" || "$new_port" != "$default_port" ]]; then
        portpart=":$new_port"
    fi

    printf '%s://%s%s%s' "$scheme" "$shown_host" "$portpart" "$suffix"
}

looks_like_ip_literal() {
    local host="$1"
    [[ "$host" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ || "$host" == *:* ]]
}

rewrite_proxy_destination_in_file() {
    local file="$1" old_scheme="$2" old_host="$3" old_port="$4" new_host="$5" new_port="$6" out="$7"
    local line target scheme host port new_target changed=0

    : > "$out"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ ! "$line" =~ ^[[:space:]]*# && "$line" =~ proxy_pass[[:space:]]+([^\;[:space:]]+) ]]; then
            target="${BASH_REMATCH[1]}"
            scheme="$(proxy_target_scheme "$target" 2>/dev/null || true)"
            host="$(proxy_target_host "$target" 2>/dev/null || true)"
            port="$(proxy_target_port "$target" 2>/dev/null || true)"
            if [[ "$scheme" == "$old_scheme" && "$host" == "$old_host" && "$port" == "$old_port" ]]; then
                new_target="$(proxy_target_with_host_port "$target" "$new_host" "$new_port" 2>/dev/null || true)"
                if [[ -n "$new_target" ]]; then
                    line="${line/"$target"/"$new_target"}"
                    changed=$((changed + 1))
                fi
            fi
        fi
        printf '%s\n' "$line" >> "$out"
    done < "$file"

    ((changed > 0))
}

change_backend_target() {
    local name="$1"
    local file="$SITES_AVAILABLE/$name"
    local -a targets=() editable_targets=()
    local target host port scheme choice old_host old_port old_scheme new_host new_port new_target backup tmp i

    [[ -f "$file" ]] || { say_err "$(tr_msg file_not_found): $file"; return 1; }
    mapfile -t targets < <(list_proxy_pass_targets "$file")
    ((${#targets[@]} > 0)) || { say_warn "$(tr_msg site_no_backend)"; return 1; }

    for target in "${targets[@]}"; do
        if proxy_target_host "$target" >/dev/null 2>&1 && proxy_target_port "$target" >/dev/null 2>&1; then
            editable_targets+=("$target")
        fi
    done
    ((${#editable_targets[@]} > 0)) || { say_warn "$(tr_msg backend_target_unsupported)"; return 1; }

    panel "$NGX_GREEN_DARK" "$(tr_msg backend_change_title)" "$(tr_msg backend_targets):"
    echo
    i=1
    for target in "${editable_targets[@]}"; do
        host="$(proxy_target_host "$target")"
        port="$(proxy_target_port "$target")"
        printf ' %b%2d)%b %s  %b[%s:%s]%b\n' "$NGX_GREEN_SOFT" "$i" "$RESET" "$target" "$NGX_GREY" "$host" "$port" "$RESET"
        ((i++))
    done

    if ((${#editable_targets[@]} == 1)); then
        choice=1
    else
        echo
        choice="$(prompt_free "$(tr_msg backend_select)")"
        [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#editable_targets[@]})) || {
            say_err "$(tr_msg invalid_choice)"
            return 1
        }
    fi

    target="${editable_targets[choice-1]}"
    old_scheme="$(proxy_target_scheme "$target")"
    old_host="$(proxy_target_host "$target")"
    old_port="$(proxy_target_port "$target")"

    if ! looks_like_ip_literal "$old_host"; then
        say_warn "$(tr_msg backend_named_warning)"
    fi

    new_host="$(prompt_free "$(tr_msg backend_new_host)" "$old_host")"
    new_host="${new_host#[}"
    new_host="${new_host%]}"
    valid_backend_host "$new_host" || { say_err "$(tr_msg invalid_host)"; return 1; }

    new_port="$(prompt_free "$(tr_msg backend_new_port)" "$old_port")"
    valid_port "$new_port" || { say_err "$(tr_msg invalid_port)"; return 1; }

    if [[ "$new_host" == "$old_host" && "$new_port" == "$old_port" ]]; then
        say_info "$(tr_msg backend_same)"
        return 0
    fi

    new_target="$(proxy_target_with_host_port "$target" "$new_host" "$new_port")" || {
        say_warn "$(tr_msg backend_target_unsupported)"
        return 1
    }

    panel "$NGX_GREEN_DARK" "$(tr_msg backend_change_title)" \
        "$(tr_msg backend_current_host): ${BOLD}${old_host}${RESET}" \
        "$(tr_msg backend_current_port): ${BOLD}${old_port}${RESET}" \
        "$(tr_msg backend_new_host): ${BOLD}${new_host}${RESET}" \
        "$(tr_msg backend_new_port): ${BOLD}${new_port}${RESET}" \
        "$(tr_msg backend_new_target): ${BOLD}${new_target}${RESET}" \
        "$(tr_msg backend_apply_all)"

    say_info "$(tr_msg backend_change_confirm)"
    confirm_yes || { say_info "$(tr_msg cancelled)"; return 0; }

    backup="$(backup_file "$file")"
    tmp="$(mktemp)"
    if ! rewrite_proxy_destination_in_file "$file" "$old_scheme" "$old_host" "$old_port" "$new_host" "$new_port" "$tmp"; then
        rm -f "${tmp:?}"
        say_warn "$(tr_msg backend_target_unsupported)"
        return 1
    fi

    cat "$tmp" > "$file"
    rm -f "${tmp:?}"
    say_info "$(tr_msg backup_created): ${NGX_CYAN}${backup}${RESET}"
    say_ok "$(tr_msg backend_changed)"

    if ! nginx_test; then
        cp -a -- "$backup" "$file"
        say_ok "$(tr_msg restored)"
        nginx_test || true
        return 1
    fi

    if confirm_default_yes "$(tr_msg reload_question)"; then
        systemctl reload-or-restart nginx && say_ok "$(tr_msg reload_ok)" || say_err "$(tr_msg reload_fail)"
    fi
}

test_backend() {
    local name="$1"
    local file="$SITES_AVAILABLE/$name" url rc=0
    url="$(first_proxy_pass "$file")"
    [[ -n "$url" ]] || { say_warn "$(tr_msg site_no_backend)"; return 1; }
    say_info "$(tr_msg backend_testing): ${BOLD}${url}${RESET}"
    if command -v curl >/dev/null 2>&1; then
        curl -kfsSIL --connect-timeout 5 --max-time 10 "$url" || rc=$?
    elif command -v wget >/dev/null 2>&1; then
        wget --no-check-certificate -S --spider --timeout=10 "$url" || rc=$?
    else
        say_err "$(tr_msg curl_missing)"
        return 1
    fi
    if [[ "$rc" -eq 0 ]]; then
        say_ok "$(tr_msg backend_ok)"
    else
        say_warn "$(tr_msg backend_fail)"
    fi
    return "$rc"
}

delete_site() {
    local name="$1"
    local file="$SITES_AVAILABLE/$name" answer stamp dir was_enabled="no" le_cert
    [[ -f "$file" ]] || return 1
    le_cert="$(sed -n "s|^[[:space:]]*ssl_certificate ${LE_LIVE}/\([^/]*\)/fullchain.pem;.*|\1|p" "$file" | head -n1)"
    is_site_enabled "$name" && was_enabled="yes" || true
    panel "$NGX_RED" "$(tr_msg site_delete)" "$(tr_msg delete_warning)" "$(tr_msg delete_confirm): ${BOLD}${name}${RESET}"
    printf '> '
    IFS= read -r answer || true
    [[ "$answer" == "$name" ]] || { say_info "$(tr_msg cancelled)"; return 0; }
    stamp="$(safe_timestamp)"
    dir="$BACKUP_ROOT/deleted-sites/$stamp"
    mkdir -p "$dir"
    cp -a -- "$file" "$dir/$name"
    if [[ -L "${SITES_ENABLED:?}/$name" ]]; then rm -f -- "${SITES_ENABLED:?}/$name"; fi
    rm -f -- "${file:?}"
    if ! nginx_test; then
        cp -a -- "$dir/$name" "$file"
        [[ "$was_enabled" == "yes" ]] && ln -s "$file" "$SITES_ENABLED/$name" 2>/dev/null || true
        say_err "$(tr_msg test_fail)"
        return 1
    fi
    say_ok "$(tr_msg delete_ok): ${NGX_CYAN}${dir}/${name}${RESET}"
    confirm_default_yes "$(tr_msg reload_question)" && systemctl reload-or-restart nginx && say_ok "$(tr_msg reload_ok)" || true
    if [[ -n "$le_cert" ]] && confirm_default_no "$(tr_msg delete_le_question)"; then
        certbot delete --non-interactive --cert-name "$le_cert" || true
    fi
}

site_actions_menu() {
    local name="$1" choice
    while true; do
        show_banner
        site_summary "$name"
        echo
        printf ' %b1)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg site_view)"
        printf ' %b2)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg site_edit)"
        printf ' %b3)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg site_enable)"
        printf ' %b4)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg site_disable)"
        printf ' %b5)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg site_change_backend)"
        printf ' %b6)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg site_test_backend)"
        printf ' %b7)%b %s\n' "$NGX_RED" "$RESET" "$(tr_msg site_delete)"
        printf ' %b8)%b %s\n' "$NGX_GREY" "$RESET" "$(tr_msg site_back)"
        echo
        choice="$(prompt_free "$(tr_msg choose_option)")"
        case "$choice" in
            1) print_file "$SITES_AVAILABLE/$name" || true; pause ;;
            2) edit_file_safe "$SITES_AVAILABLE/$name" || true; pause ;;
            3) enable_site "$name" || true; pause ;;
            4) disable_site "$name" || true; pause ;;
            5) change_backend_target "$name" || true; pause ;;
            6) test_backend "$name" || true; pause ;;
            7) delete_site "$name" || true; pause; [[ -f "$SITES_AVAILABLE/$name" ]] || return 0 ;;
            8) return 0 ;;
            *) say_err "$(tr_msg invalid_choice)"; pause ;;
        esac
    done
}

sites_menu() {
    local choice i state
    while true; do
        show_banner
        panel "$NGX_GREEN" "$(tr_msg sites_title)" "${SITES_AVAILABLE}"
        list_sites_array
        if ((${#SITE_LIST[@]} == 0)); then
            say_warn "$(tr_msg sites_none)"
            pause
            return 0
        fi
        echo
        i=1
        for name in "${SITE_LIST[@]}"; do
            if is_site_enabled "$name"; then
                state="${NGX_GREEN_SOFT}●${RESET}"
            else
                state="${NGX_GREY}○${RESET}"
            fi
            printf ' %b%2d)%b %b %s\n' "$NGX_GREEN_SOFT" "$i" "$RESET" "$state" "$name"
            ((i++))
        done
        printf ' %b 0)%b %s\n' "$NGX_GREY" "$RESET" "$(tr_msg site_back)"
        echo
        choice="$(prompt_free "$(tr_msg site_select)")"
        [[ "$choice" == "0" ]] && return 0
        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#SITE_LIST[@]})); then
            site_actions_menu "${SITE_LIST[choice-1]}"
        else
            say_err "$(tr_msg invalid_choice)"
            pause
        fi
    done
}

# ── New reverse-proxy wizard ──────────────────────────────────────────────────

# The redirect also answers the ACME challenge, so a site does not depend on what
# the default vhost of the container does with port 80.
http_block() {
    cat <<VHOST
server {
    listen 80;
    listen [::]:80;
    server_name ${1};

    location ^~ /.well-known/acme-challenge/ {
        root ${ACME_ROOT};
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}
VHOST
}

# The TLS files of a site: the certificate of its snippet, or the ones Let's
# Encrypt will write for it.
tls_lines() {
    local fqdn="$1" snippet="$2"
    if [[ -n "$snippet" ]]; then
        echo "    include ${snippet};"
    else
        echo "    ssl_certificate ${LE_LIVE}/${fqdn}/fullchain.pem;"
        echo "    ssl_certificate_key ${LE_LIVE}/${fqdn}/privkey.pem;"
        echo "    include ${TLS_COMMON};"
    fi
}

vhost_body() {
    local fqdn="$1" target="$2" verify="$3" snippet="$4"
    echo "# ${MANAGED_MARKER}"
    echo "# Created: $(date -Is)"
    echo
    http_block "$fqdn"
    echo
    echo "server {"
    echo "    listen 443 ssl;"
    echo "    listen [::]:443 ssl;"
    echo "    server_name ${fqdn};"
    echo
    tls_lines "$fqdn" "$snippet"
    echo
    echo "    location / {"
    echo "        proxy_pass ${target};"
    echo "        include ${PROXY_SNIPPET};"
    echo "        proxy_intercept_errors off;"
    if [[ "$target" == https://* ]]; then
        echo "        proxy_ssl_server_name on;"
        if [[ "$verify" == "yes" ]]; then
            echo "        proxy_ssl_verify on;"
            echo "        proxy_ssl_verify_depth 3;"
            echo "        proxy_ssl_trusted_certificate ${SYSTEM_CA_BUNDLE};"
        else
            echo "        proxy_ssl_verify off;"
        fi
    fi
    echo "    }"
    echo "}"
}

list_cert_snippets() {
    local f
    for f in "$SNIPPETS_DIR"/*; do
        [[ -f "$f" && "$(basename "$f")" != "snakeoil.conf" ]] || continue
        if grep -qE '^[[:space:]]*ssl_certificate[[:space:]]' "$f"; then
            printf '%s\n' "$f"
        fi
    done
}

CERT_CHOICE=""
CERT_SNIPPET=""
OWN_CERT=""
OWN_KEY=""
OWN_SNIPPET=""

# CERT_CHOICE ends up as letsencrypt, own or snippet.
choose_certificate() {
    local fqdn="$1" choice f i
    local -a snippets=()
    mapfile -t snippets < <(list_cert_snippets)

    panel "$NGX_GREEN_DARK" "$(tr_msg cert_title)"
    printf ' %b1)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg cert_le)"
    printf ' %b2)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg cert_own)"
    i=3
    for f in "${snippets[@]}"; do
        printf ' %b%d)%b %s: %s\n' "$NGX_GREEN_SOFT" "$i" "$RESET" "$(tr_msg cert_snippet)" "$(basename "$f")"
        ((i++))
    done
    echo
    choice="$(prompt_free "$(tr_msg choose_option)" "1")"
    [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice < i)) || { say_err "$(tr_msg invalid_choice)"; return 1; }

    case "$choice" in
        1) CERT_CHOICE="letsencrypt" ;;
        2)
            CERT_CHOICE="own"
            OWN_CERT="$(prompt_free "$(tr_msg prompt_cert_path)")"
            OWN_KEY="$(prompt_free "$(tr_msg prompt_key_path)")"
            [[ -f "$OWN_CERT" ]] || { say_err "$(tr_msg file_not_found): $OWN_CERT"; return 1; }
            [[ -f "$OWN_KEY" ]] || { say_err "$(tr_msg file_not_found): $OWN_KEY"; return 1; }
            if [[ "$(openssl x509 -in "$OWN_CERT" -noout -pubkey 2>/dev/null | sha256sum)" != \
                  "$(openssl pkey -in "$OWN_KEY" -pubout 2>/dev/null | sha256sum)" ]]; then
                say_err "$(tr_msg cert_mismatch)"
                return 1
            fi
            OWN_SNIPPET="$SNIPPETS_DIR/tls-${fqdn}.conf"
            [[ ! -e "$OWN_SNIPPET" ]] || { say_err "$(tr_msg already_exists): $OWN_SNIPPET"; return 1; }
            CERT_SNIPPET="$OWN_SNIPPET"
            ;;
        *)
            CERT_CHOICE="snippet"
            CERT_SNIPPET="${snippets[choice-3]}"
            ;;
    esac
}

ensure_certbot() {
    command -v certbot >/dev/null 2>&1 && return 0
    say_info "$(tr_msg certbot_installing)"
    DEBIAN_FRONTEND=noninteractive apt-get install -y certbot
}

# Keeps the certificates in use fresh: Nginx only reads them when it loads.
install_deploy_hook() {
    mkdir -p "$(dirname "$LE_DEPLOY_HOOK")"
    printf '#!/bin/sh\nsystemctl reload nginx\n' >"$LE_DEPLOY_HOOK"
    chmod 0755 "$LE_DEPLOY_HOOK"
}

remove_site() {
    local name="${1:?}"
    rm -f -- "${SITES_ENABLED:?}/${name}" "${SITES_AVAILABLE:?}/${name}"
}

# A site has to answer on port 80 for Let's Encrypt to check it, and its HTTPS
# part cannot load before the certificate exists, so the file is written twice.
request_certificate() {
    local fqdn="$1" email="$2"
    local -a contact=(--register-unsafely-without-email)
    [[ -n "$email" ]] && contact=(--email "$email")

    ensure_certbot || { say_err "$(tr_msg install_failed)"; return 1; }
    install_deploy_hook
    install -d -m 0755 "$ACME_ROOT"

    { echo "# ${MANAGED_MARKER}"; http_block "$fqdn"; } | write_public "$SITES_AVAILABLE/$fqdn"
    ln -s "$SITES_AVAILABLE/$fqdn" "$SITES_ENABLED/$fqdn"
    if ! nginx_test || ! systemctl reload-or-restart nginx; then
        remove_site "$fqdn"
        say_err "$(tr_msg create_rolled_back)"
        return 1
    fi

    # a reload returns before the workers have taken the new site
    sleep 1
    say_info "$(tr_msg le_requesting)"
    if ! certbot certonly --webroot --webroot-path "$ACME_ROOT" --cert-name "$fqdn" --domains "$fqdn" \
        --non-interactive --agree-tos --keep-until-expiring "${contact[@]}"; then
        remove_site "$fqdn"
        systemctl reload-or-restart nginx || true
        say_err "$(tr_msg le_failed)"
        return 1
    fi
}

write_own_snippet() {
    {
        echo "# ${MANAGED_MARKER}"
        echo "ssl_certificate ${OWN_CERT};"
        echo "ssl_certificate_key ${OWN_KEY};"
        echo "include ${TLS_COMMON};"
    } | write_public "$OWN_SNIPPET"
}

add_reverse_proxy() {
    local fqdn backend_host backend_port scheme_choice scheme verify="no" enable="yes" email=""
    local file tmp target

    show_banner
    panel "$NGX_GREEN_DARK" "$(tr_msg wizard_title)" \
        "$(tr_msg wizard_intro1)" \
        "$(tr_msg wizard_intro2)" \
        "$(tr_msg wizard_intro3)"

    if ! base_is_ready; then
        say_info "$(tr_msg base_needed)"
        setup_base || return 1
    fi

    fqdn="$(prompt_free "$(tr_msg prompt_fqdn)")"
    valid_fqdn "$fqdn" || { say_err "$(tr_msg invalid_fqdn)"; return 1; }
    file="$SITES_AVAILABLE/$fqdn"
    [[ ! -e "$file" ]] || { say_err "$(tr_msg already_exists): $file"; return 1; }

    backend_host="$(prompt_free "$(tr_msg prompt_backend_host)")"
    backend_host="${backend_host#[}"
    backend_host="${backend_host%]}"
    valid_backend_host "$backend_host" || { say_err "$(tr_msg invalid_host)"; return 1; }

    scheme_choice="$(prompt_free "$(tr_msg prompt_backend_scheme)" "1")"
    case "$scheme_choice" in
        1|http) scheme="http" ;;
        2|https) scheme="https" ;;
        *) say_err "$(tr_msg invalid_choice)"; return 1 ;;
    esac

    if [[ "$scheme" == "https" ]]; then
        backend_port="$(prompt_free "$(tr_msg prompt_backend_port)" "443")"
    else
        backend_port="$(prompt_free "$(tr_msg prompt_backend_port)" "80")"
    fi
    valid_port "$backend_port" || { say_err "$(tr_msg invalid_port)"; return 1; }

    if [[ "$scheme" == "https" ]]; then
        confirm_default_no "$(tr_msg prompt_backend_verify)" && verify="yes" || verify="no"
    fi

    CERT_SNIPPET=""
    choose_certificate "$fqdn" || return 1

    if [[ "$CERT_CHOICE" == "letsencrypt" ]]; then
        panel "$NGX_AMBER" "$(tr_msg cert_title)" "$(tr_msg le_needs)" "$(tr_msg le_terms)"
        email="$(prompt_free "$(tr_msg prompt_email)")"
        [[ -z "$email" ]] || valid_email "$email" || { say_err "$(tr_msg invalid_email)"; return 1; }
    elif ! confirm_default_yes "$(tr_msg prompt_enable)"; then
        enable="no"
    fi

    mkdir -p "$SITES_AVAILABLE" "$SITES_ENABLED"
    tmp="$(mktemp)"
    target="${scheme}://$(bracket_ipv6 "$backend_host"):${backend_port}"
    vhost_body "$fqdn" "$target" "$verify" "$CERT_SNIPPET" >"$tmp"

    panel "$NGX_CYAN" "$(tr_msg preview_title)" "FQDN: ${fqdn}" "Backend: ${target}"
    echo
    sed 's/^/  /' "$tmp"
    say_info "$(tr_msg create_question)"
    if ! confirm_yes; then
        rm -f "${tmp:?}"
        say_info "$(tr_msg cancelled)"
        return 0
    fi

    if [[ "$CERT_CHOICE" == "letsencrypt" ]] && ! request_certificate "$fqdn" "$email"; then
        rm -f "${tmp:?}"
        return 1
    fi
    [[ "$CERT_CHOICE" != "own" ]] || write_own_snippet

    cat "$tmp" >"$file"
    chmod 0644 "$file"
    rm -f "${tmp:?}"
    if [[ "$enable" == "yes" && ! -e "$SITES_ENABLED/$fqdn" ]]; then
        ln -s "$file" "$SITES_ENABLED/$fqdn"
    fi

    if ! nginx_test; then
        remove_site "$fqdn"
        [[ "$CERT_CHOICE" != "own" ]] || rm -f -- "${OWN_SNIPPET:?}"
        say_err "$(tr_msg create_rolled_back)"
        nginx_test || true
        return 1
    fi

    say_ok "$(tr_msg created): ${NGX_CYAN}${file}${RESET}"
    if [[ "$enable" == "yes" ]] && confirm_default_yes "$(tr_msg reload_question)"; then
        systemctl reload-or-restart nginx && say_ok "$(tr_msg reload_ok)" || say_err "$(tr_msg reload_fail)"
    fi
}

# ── Important files / snippets ────────────────────────────────────────────────

SELECTED_FILE=""
choose_file_from_dir() {
    local dir="$1" title="$2" choice i f
    SELECTED_FILE=""
    mapfile -t FILE_LIST < <(find "$dir" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort)
    ((${#FILE_LIST[@]})) || { say_warn "$(tr_msg sites_none)"; return 1; }
    panel "$NGX_GREEN_DARK" "$title" "$dir"
    i=1
    for f in "${FILE_LIST[@]}"; do
        printf ' %b%2d)%b %s\n' "$NGX_GREEN_SOFT" "$i" "$RESET" "$f"
        ((i++))
    done
    printf ' %b 0)%b %s\n' "$NGX_GREY" "$RESET" "$(tr_msg site_back)"
    choice="$(prompt_free "$(tr_msg choose_option)")"
    [[ "$choice" == "0" ]] && return 1
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice>=1 && choice<=${#FILE_LIST[@]})); then
        SELECTED_FILE="$dir/${FILE_LIST[choice-1]}"
        return 0
    fi
    say_err "$(tr_msg invalid_choice)"
    return 1
}

configs_menu() {
    local choice file default_vhost
    while true; do
        show_banner
        default_vhost="$(find_default_vhost 2>/dev/null || true)"
        panel "$NGX_GREEN" "$(tr_msg config_title)" \
            "nginx.conf: ${NGINX_CONF}" \
            "$(tr_msg config_default): ${default_vhost:-$(tr_msg not_detected)}" \
            "TLS: ${TLS_COMMON}" \
            "Proxy: ${PROXY_SNIPPET}" \
            "WebSocket: ${WEBSOCKET_MAP}"
        echo
        printf ' %b1)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg config_nginx)"
        printf ' %b2)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg config_default)"
        printf ' %b3)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg config_tls)"
        printf ' %b4)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg config_proxy)"
        printf ' %b5)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg config_ws)"
        printf ' %b6)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg config_other_snippet)"
        printf ' %b7)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg config_other_conf)"
        printf ' %b8)%b %s\n' "$NGX_GREY" "$RESET" "$(tr_msg config_back)"
        choice="$(prompt_free "$(tr_msg choose_option)")"
        file=""
        case "$choice" in
            1) file="$NGINX_CONF" ;;
            2) file="$default_vhost" ;;
            3) file="$TLS_COMMON" ;;
            4) file="$PROXY_SNIPPET" ;;
            5) file="$WEBSOCKET_MAP" ;;
            6) if choose_file_from_dir "$SNIPPETS_DIR" "$(tr_msg config_other_snippet)"; then file="$SELECTED_FILE"; fi ;;
            7) if choose_file_from_dir "$CONF_D" "$(tr_msg config_other_conf)"; then file="$SELECTED_FILE"; fi ;;
            8) return 0 ;;
            *) say_err "$(tr_msg invalid_choice)"; pause; continue ;;
        esac
        [[ -n "$file" ]] && edit_file_safe "$file" || true
        pause
    done
}

# ── Logs ──────────────────────────────────────────────────────────────────────

show_log_tail() {
    local file="$1"
    [[ -f "$file" ]] || { say_err "$(tr_msg file_not_found): $file"; return 1; }
    echo
    tail -n 120 "$file"
}

logs_menu() {
    local choice file
    while true; do
        show_banner
        panel "$NGX_GREEN" "$(tr_msg logs_title)" "/var/log/nginx"
        echo
        printf ' %b1)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg logs_error)"
        printf ' %b2)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg logs_access)"
        printf ' %b3)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg logs_journal)"
        printf ' %b4)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg logs_choose)"
        printf ' %b5)%b %s\n' "$NGX_GREY" "$RESET" "$(tr_msg logs_back)"
        choice="$(prompt_free "$(tr_msg choose_option)")"
        case "$choice" in
            1) show_log_tail /var/log/nginx/error.log || true; pause ;;
            2) show_log_tail /var/log/nginx/access.log || true; pause ;;
            3) journalctl -u nginx -n 120 --no-pager || true; pause ;;
            4) file=""; if choose_file_from_dir /var/log/nginx "$(tr_msg logs_choose)"; then file="$SELECTED_FILE"; fi; [[ -n "$file" ]] && show_log_tail "$file" || true; pause ;;
            5) return 0 ;;
            *) say_err "$(tr_msg invalid_choice)"; pause ;;
        esac
    done
}

# ── Full backups / restore ────────────────────────────────────────────────────

create_full_backup() {
    local stamp archive
    stamp="$(safe_timestamp)"
    archive="$BACKUP_ROOT/nginx-full-${stamp}.tar.gz"
    tar -C / -czf "$archive" "${NGINX_DIR#/}"
    chmod 600 "$archive"
    say_ok "$(tr_msg backup_full_ok): ${NGX_CYAN}${archive}${RESET}"
}

list_full_backups() {
    mapfile -t FULL_BACKUPS < <(find "$BACKUP_ROOT" -maxdepth 1 -type f -name 'nginx-full-*.tar.gz' -printf '%f\n' 2>/dev/null | sort -r)
}

restore_full_backup() {
    local choice i archive entries safety
    list_full_backups
    if ((${#FULL_BACKUPS[@]} == 0)); then
        say_warn "$(tr_msg backup_none)"
        return 0
    fi
    panel "$NGX_RED" "$(tr_msg backup_restore)" "$(tr_msg restore_warning)"
    i=1
    for f in "${FULL_BACKUPS[@]}"; do
        printf ' %b%2d)%b %s\n' "$NGX_GREEN_SOFT" "$i" "$RESET" "$f"
        ((i++))
    done
    printf ' %b 0)%b %s\n' "$NGX_GREY" "$RESET" "$(tr_msg site_back)"
    choice="$(prompt_free "$(tr_msg choose_option)")"
    [[ "$choice" == "0" ]] && return 0
    [[ "$choice" =~ ^[0-9]+$ ]] && ((choice>=1 && choice<=${#FULL_BACKUPS[@]})) || { say_err "$(tr_msg invalid_choice)"; return 1; }
    archive="$BACKUP_ROOT/${FULL_BACKUPS[choice-1]}"
    entries="$(tar -tzf "$archive" 2>/dev/null || true)"
    if [[ -z "$entries" ]] || grep -qv "^${NGINX_DIR#/}/" <<<"$entries"; then
        say_err "$(tr_msg restore_bad_archive)"
        return 1
    fi
    confirm_yes || { say_info "$(tr_msg cancelled)"; return 0; }

    safety="$BACKUP_ROOT/nginx-full-before-restore-$(safe_timestamp).tar.gz"
    tar -C / -czf "$safety" "${NGINX_DIR#/}"
    chmod 600 "$safety"
    rm -rf "${NGINX_DIR:?}"
    if ! tar -C / -xzf "$archive" || ! nginx_test; then
        say_err "$(tr_msg restore_failed)"
        rm -rf "${NGINX_DIR:?}"
        tar -C / -xzf "$safety"
        nginx_test || true
        return 1
    fi
    systemctl reload-or-restart nginx
    say_ok "$(tr_msg restore_ok)"
}

backups_menu() {
    local choice
    while true; do
        show_banner
        panel "$NGX_GREEN" "$(tr_msg backup_title)" "$BACKUP_ROOT"
        echo
        printf ' %b1)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg backup_full)"
        printf ' %b2)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg backup_list)"
        printf ' %b3)%b %s\n' "$NGX_RED" "$RESET" "$(tr_msg backup_restore)"
        printf ' %b4)%b %s\n' "$NGX_GREY" "$RESET" "$(tr_msg backup_back)"
        choice="$(prompt_free "$(tr_msg choose_option)")"
        case "$choice" in
            1) create_full_backup || true; pause ;;
            2) list_full_backups; echo; if ((${#FULL_BACKUPS[@]})); then printf '  %s\n' "${FULL_BACKUPS[@]}"; else say_warn "$(tr_msg backup_none)"; fi; pause ;;
            3) restore_full_backup || true; pause ;;
            4) return 0 ;;
            *) say_err "$(tr_msg invalid_choice)"; pause ;;
        esac
    done
}

# Started through bash <(curl ...) the script is a pipe, not a file to copy.
install_command() {
    local tmp
    if [[ -f "$SCRIPT_PATH" && "$SCRIPT_PATH" -ef "$COMMAND_PATH" ]]; then
        say_info "$(tr_msg command_already)"
        return 0
    fi
    if [[ -f "$SCRIPT_PATH" ]]; then
        install -m 0755 "$SCRIPT_PATH" "$COMMAND_PATH"
    else
        tmp="$(mktemp)"
        if ! curl -fsSL "$SCRIPT_URL" -o "$tmp" || ! bash -n "$tmp"; then
            rm -f "${tmp:?}"
            say_err "$(tr_msg command_install_fail)"
            return 1
        fi
        install -m 0755 "$tmp" "$COMMAND_PATH"
        rm -f "${tmp:?}"
    fi
    say_ok "$(tr_msg command_installed): ${NGX_CYAN}${COMMAND_PATH}${RESET}"
    say_info "$(tr_msg command_run): ${BOLD}nginx-proxy${RESET}"
}

uninstall_nginx() {
    local -a packages=()
    panel "$NGX_RED" "$(tr_msg menu_uninstall)" "$(tr_msg uninstall_body_1)" "$(tr_msg uninstall_body_2)"
    confirm_yes || { say_info "$(tr_msg cancelled)"; return 0; }

    create_full_backup
    mapfile -t packages < <(dpkg-query -W -f='${db:Status-Status} ${Package}\n' 'nginx*' 'libnginx-mod-*' 2>/dev/null |
        awk '$1=="installed" {print $2}')
    if ! DEBIAN_FRONTEND=noninteractive apt-get purge -y "${packages[@]}"; then
        say_err "$(tr_msg install_failed)"
        return 1
    fi
    rm -rf -- "${NGINX_DIR:?}"
    rm -f -- "${LE_DEPLOY_HOOK:?}" "${COMMAND_PATH:?}"
    say_ok "$(tr_msg uninstall_ok)"
    exit 0
}

# ── Main menu ─────────────────────────────────────────────────────────────────

menu_action() {
    "$@" || true
}

main_menu() {
    local choice
    while true; do
        show_banner
        show_status
        echo
        printf ' %b1)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg menu_sites)"
        printf ' %b2)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg menu_add)"
        printf ' %b3)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg menu_configs)"
        printf ' %b4)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg menu_check)"
        printf ' %b5)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg menu_reload)"
        printf ' %b6)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg menu_logs)"
        printf ' %b7)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg menu_backup)"
        printf ' %b8)%b %s\n' "$NGX_GREEN_SOFT" "$RESET" "$(tr_msg menu_install_cmd)"
        printf ' %b9)%b %s\n' "$NGX_RED" "$RESET" "$(tr_msg menu_uninstall)"
        printf ' %b10)%b %s\n' "$NGX_GREY" "$RESET" "$(tr_msg menu_quit)"
        echo
        choice="$(prompt_free "$(tr_msg choose_option)")"
        case "$choice" in
            1) menu_action sites_menu ;;
            2) menu_action add_reverse_proxy; pause ;;
            3) menu_action configs_menu ;;
            4) menu_action nginx_test; pause ;;
            5) menu_action reload_nginx; pause ;;
            6) menu_action logs_menu ;;
            7) menu_action backups_menu ;;
            8) menu_action install_command; pause ;;
            9) menu_action uninstall_nginx; pause ;;
            10) echo; say_info "$(tr_msg bye)"; exit 0 ;;
            *) say_err "$(tr_msg invalid_choice)"; pause ;;
        esac
    done
}

require_root
require_system
ensure_nginx
main_menu
