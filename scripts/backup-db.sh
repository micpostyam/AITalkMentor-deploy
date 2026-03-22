#!/bin/bash
# Backup PostgreSQL databases for all environments
# Usage: ./backup-db.sh [staging|production|all]
# Add to crontab: 0 3 * * * /opt/apps/aitalkmentor-deploy/scripts/backup-db.sh all

set -e

BACKUP_DIR="/opt/backups/aitalkmentor"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

backup_env() {
    local env=$1
    local container="aitalkmentor-${env}-db"

    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "⚠️  Container $container not running, skipping."
        return
    fi

    local db_user
    db_user=$(docker exec "$container" printenv POSTGRES_USER)
    local db_name
    db_name=$(docker exec "$container" printenv POSTGRES_DB)

    local backup_file="${BACKUP_DIR}/${env}_${DATE}.sql.gz"

    echo "📦 Backing up $env ($db_name)..."
    docker exec "$container" pg_dump -U "$db_user" "$db_name" | gzip > "$backup_file"
    echo "✅ Saved: $backup_file ($(du -h "$backup_file" | cut -f1))"
}

cleanup() {
    echo "🧹 Removing backups older than ${RETENTION_DAYS} days..."
    find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
}

case "${1:-all}" in
    staging)    backup_env staging ;;
    production) backup_env prod ;;
    all)        backup_env staging; backup_env prod ;;
    *)          echo "Usage: $0 [staging|production|all]"; exit 1 ;;
esac

cleanup
echo "🎉 Backup complete."
