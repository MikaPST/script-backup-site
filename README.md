# 💾 Script de Sauvegarde des Sites Web et Bases de Données 📦

[🇫🇷 Lire en Français](README.md) | [🇬🇧 Read in English](README_EN.md)

Ce script bash génère les archives de sauvegarde des sites web et de leurs bases de données directement sur le serveur hébergeur, et les prépare pour être récupérées via FTP par le script client.

## 🌟 Fonctionnalités

- 🗄️ Sauvegarde et compression des bases de données via `mysqldump`.
- 📦 Archivage et compression des fichiers des sites web via `tar`.
- 📝 Gestion des logs des sauvegardes et des actions menées.
- 📂 Création automatique des répertoires de sauvegarde et de logs si nécessaire.
- ✅ Vérification du succès de chaque opération avec gestion des erreurs.

## 📋 Prérequis

- `mysqldump` doit être disponible sur le serveur.
- `tar` et `gzip` doivent être installés sur le serveur.
- Les sites web doivent être hébergés dans `/home/{USER}/{site_name}`.
- L'utilisateur MySQL doit avoir les droits suffisants pour effectuer un dump des bases de données.

## 🛠️ Utilisation

1. Clonez ce dépôt ou téléchargez le script sur votre serveur hébergeur.
2. Modifiez les variables en haut du script pour configurer les détails de votre environnement.
3. Rendez le script exécutable : `chmod +x script_backup_server.sh`
4. Exécutez le script manuellement ou planifiez-le via un cron job.

### ⏰ Exemple de Cron Job

Pour exécuter le script tous les jours à 2h du matin :

```bash
0 2 * * * /chemin/vers/script_backup_server.sh
```

## 🔧 Variables à Configurer

- `USER` : Nom d'utilisateur système sous lequel sont hébergés les sites.
- `DBADMIN` : Suffixe du nom d'utilisateur MySQL utilisé pour les dumps (ex: `DUMP` → utilisateur `USER_DUMP`).
- `DBPW` : Mot de passe de l'utilisateur MySQL.
- `BACKUP_PATH` : Chemin vers le répertoire où les archives seront stockées.
- `LOGS_PATH` : Chemin vers le répertoire où les logs seront enregistrés.

## 📝 Exemple de Script

```bash
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

    if [ ! -d "$site_path" ]; then
        log "[ERROR] Le dossier du site ${site_name} est introuvable : $site_path"
        return 1
    fi

    tar -zcf "$output_file" -C "/home/${USER}" "${site_name}"

    if [ $? -ne 0 ]; then
        log "[ERROR] Échec de la compression du site ${site_name}."
        return 1
    fi

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
```

## 📖 Explications des Fonctions

### 📝 Fonction log
Définie en tout premier dans le script. Enregistre un message avec un horodatage dans le fichier de logs du jour.

```bash
log() {
    local message=$1
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" >> "$LOGS_PATH/${DATE}_script_backup_logs"
}
```

### 📁 Vérification et Création des Répertoires
Vérifie si les répertoires de logs et de sauvegarde existent, et les crée si nécessaire.

```bash
if [ ! -d "$LOGS_PATH" ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Le répertoire des logs $LOGS_PATH n'existe pas. Création en cours..."
    mkdir -p "$LOGS_PATH"
fi

if [ ! -d "$BACKUP_PATH" ]; then
    log "Le répertoire de sauvegarde $BACKUP_PATH n'existe pas. Création en cours..."
    mkdir -p "$BACKUP_PATH"
fi
```

### 🗄️ Fonction backup_database
Effectue un dump de la base de données via `mysqldump`, compresse le résultat avec `gzip`, et vérifie le succès de chaque étape. Passe par un fichier temporaire pour détecter les erreurs `mysqldump` avant de compresser.

```bash
backup_database() {
    local db_name=$1
    local output_file="${BACKUP_PATH}/bdd_${db_name}_${DATE}.sql.gz"

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
    # ...
}
```

### 📦 Fonction backup_site
Archive et compresse les fichiers du site via `tar`. Vérifie au préalable que le dossier du site existe, puis contrôle que l'archive produite n'est pas vide.

```bash
backup_site() {
    local site_name=$1
    local output_file="${BACKUP_PATH}/site_${site_name}_${DATE}.tgz"
    local site_path="/home/${USER}/${site_name}"

    if [ ! -d "$site_path" ]; then
        log "[ERROR] Le dossier du site ${site_name} est introuvable : $site_path"
        return 1
    fi

    tar -zcf "$output_file" -C "/home/${USER}" "${site_name}"
    # ...
}
```

### 🔗 Tableau d'Association et de Correspondance
Définit une table associative qui fait correspondre chaque site web à sa base de données. Si un site n'a pas de base de données, la valeur est laissée vide.

```bash
declare -A SITES_DBS=(
    ["exemplesite01.com"]="db_site01"
    ["exemplesite02.com"]="db_site02"
    ["exemplesite03.com"]="db_site03"
    ["exemplesite04.com"]="" # Laisser vide si le site n'a pas de base de données
    ["exemplesite05.com"]="db_site05"
    ["exemplesite06.com"]="db_site06"
)
```

### 🔄 Traitement et Gestion des Sauvegardes
Parcourt tous les sites définis dans le tableau associatif `SITES_DBS`, sauvegarde la base de données si elle existe, puis archive les fichiers du site.

```bash
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
```

## 🗂️ Format des Archives Produites

Les archives générées suivent cette convention de nommage, compatible avec le script client :

| Type | Format | Exemple |
|---|---|---|
| Base de données | `bdd_{db_name}_{YYYY-MM-DD}.sql.gz` | `bdd_db_site01_2025-01-15.sql.gz` |
| Site web | `site_{site_name}_{YYYY-MM-DD}.tgz` | `site_exemplesite01.com_2025-01-15.tgz` |

## 🔗 Script Client Associé

Ce script hébergeur fonctionne en tandem avec le **script client** disponible dans ce dépôt : [lien vers le dépôt du script client].

Le script client se charge de :
- Récupérer les archives produites par ce script via FTP.
- Gérer la rétention locale des archives (suppression des anciennes sauvegardes).

## 📜 License
Ce script est sous licence **MIT License**.

## 🤝 Contribution
Les contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou à soumettre une pull request.
