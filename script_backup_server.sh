#!/bin/bash

# Variables
USER="USER"
DBADMIN="DUMP"
DBPW="PASSWORD"
BACKUP_PATH="/CHEMIN/DE/SAUVEGARDE"
LOGS_PATH="/CHEMIN/DE/LOGS"
DATE=$(date +"%Y-%m-%d")

# Fonction pour enregistrer les logs (définie en premier)
log() {
    local message=$1
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" >> "$LOGS_PATH/${DATE}_script_backup_logs"
}

# Vérifier si le répertoire des logs existe
if [ ! -d "$LOGS_PATH" ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Le répertoire des logs $LOGS_PATH n'existe pas. Création en cours..."
    mkdir -p "$LOGS_PATH"
fi

# Vérifier si le répertoire de sauvegarde existe
if [ ! -d "$BACKUP_PATH" ]; then
    log "Le répertoire de sauvegarde $BACKUP_PATH n'existe pas. Création en cours..."
    mkdir -p "$BACKUP_PATH"
fi

# Fonction pour sauvegarder une base de données
backup_database() {
    local db_name=$1
    local output_file="${BACKUP_PATH}/bdd_${db_name}_${DATE}.sql.gz"

    log "[INFO] Sauvegarde et compression de la base de données ${db_name}..."

    # Utiliser un fichier temporaire pour détecter les erreurs mysqldump avant de compresser
    local tmp_file
    tmp_file=$(mktemp "${BACKUP_PATH}/bdd_${db_name}_${DATE}.XXXXXX.sql")

    mysqldump -u "${USER}_${DBADMIN}" -p"${DBPW}" "${USER}_${db_name}" > "$tmp_file"

    if [ $? -ne 0 ]; then
        log "[ERROR] Échec de mysqldump pour la base de données ${db_name}."
        rm -f "$tmp_file"
        return 1
    fi

    gzip -c "$tmp_file" > "$output_file"
    rm -f "$tmp_file"

    # Vérifier que le fichier produit n'est pas vide
    if [ ! -s "$output_file" ]; then
        log "[ERROR] Le fichier de sauvegarde de la base de données ${db_name} est vide ou absent."
        return 1
    fi

    log "[SUCCESS] Sauvegarde de la base de données ${db_name} terminée : $(basename "$output_file")"
}

# Fonction pour sauvegarder un site
backup_site() {
    local site_name=$1
    local output_file="${BACKUP_PATH}/site_${site_name}_${DATE}.tgz"
    local site_path="/home/${USER}/${site_name}"

    log "[INFO] Sauvegarde et compression du site ${site_name}..."

    # Vérifier que le dossier du site existe avant de lancer tar
    if [ ! -d "$site_path" ]; then
        log "[ERROR] Le dossier du site ${site_name} est introuvable : $site_path"
        return 1
    fi

    tar -zcf "$output_file" -C "/home/${USER}" "${site_name}"

    if [ $? -ne 0 ]; then
        log "[ERROR] Échec de la compression du site ${site_name}."
        return 1
    fi

    # Vérifier que le fichier produit n'est pas vide
    if [ ! -s "$output_file" ]; then
        log "[ERROR] Le fichier de sauvegarde du site ${site_name} est vide ou absent."
        return 1
    fi

    log "[SUCCESS] Sauvegarde du site ${site_name} terminée : $(basename "$output_file")"
}

# Définition des sites et de leurs bases de données correspondantes
declare -A SITES_DBS=(
    ["exemplesite01.com"]="db_site01"
    ["exemplesite02.com"]="db_site02"
    ["exemplesite03.com"]="db_site03"
    ["exemplesite04.com"]="" # Laisser vide si le site n'a pas de base de données
    ["exemplesite05.com"]="db_site05"
    ["exemplesite06.com"]="db_site06"
)

# Parcourir tous les sites, sauvegarder la BDD puis le site
for site_name in "${!SITES_DBS[@]}"; do
    db_name=${SITES_DBS[$site_name]}

    log "========================================================================================"
    log "Début du traitement pour le site $site_name"
    log "========================================================================================"

    if [ -n "$db_name" ]; then
        backup_database "$db_name"
    else
        log "[WARNING] Aucune base de données associée pour le site $site_name"
    fi

    backup_site "$site_name"

    log "========================================================================================"
    log "Fin du traitement pour le site $site_name"
    log "========================================================================================"
    log ""
done
