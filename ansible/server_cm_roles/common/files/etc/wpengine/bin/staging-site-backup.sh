#!/bin/bash
#
# A very simple script to backup a staging site.
#
# USAGE: staging-site-backup.sh sitename
#

if [[ $# -ne 1 ]];
then
    echo "ERROR: Failed to pass in sitename"
    exit 1
fi

SITE=$1
TIMESTAMP=`date +"%Y%m%d%H%M%S"`

echo "Backing up site: ${SITE}"

# Validate directories we need exist
PRODSITE="/nas/wp/www/sites/${SITE}"
PRODSITE_PRIVATE="${PRODSITE}/_wpeprivate"
STAGINGSITE="/nas/wp/www/staging/${SITE}"

for D in ${PRODSITE} ${PRODSITE_PRIVATE} ${STAGINGSITE};
do
    if [[ ! -d ${D} ]];
    then
        echo "ERROR: Missing directory: $D"
        exit 2
    fi
done

# Fail if we don't have at least 20% free disk
USED=`df ${STAGINGSITE} | awk '{ print $5 }' | tail -n 1 | sed 's/%//'`

if (( ${USED} > 80 ));
then
    echo "ERROR: Disk more than 80% full"
    exit 3
fi

echo "Backup staging database"
DB_PASS=`egrep '^define.*DB_PASSWORD' ${STAGINGSITE}/wp-config.php | awk -F"'" '{print $4}' | head -n 1`
DB_BACKUP_FILE="${PRODSITE_PRIVATE}/mysql_staging_${TIMESTAMP}.sql"

mysqldump --skip-extended-insert -u ${SITE} -p${DB_PASS} snapshot_${SITE} >${DB_BACKUP_FILE}

if [[ $? -ne 0 ]]; then
    echo "ERROR: mysqldump failed"
    exit 4
fi

echo "Backup staging files"
STAGING_SIZE_KB=`du -s ${STAGINGSITE}`  # We assume worst case
AVAILABLE_KB=`df /nas | tail -n 1| awk '{print $4}'`

if (( $STAGING_SIZE_KB > $AVAILABLE_KB ));
then
    echo "ERROR: Staging site too large to backup"
    exit 5
fi

cd /nas/wp/www/staging

TAR_BACKUP_FILE="${PRODSITE_PRIVATE}/staging_${TIMESTAMP}.tar.gz"
tar -cvzf ${TAR_BACKUP_FILE} ${SITE} || { cd -; echo "ERROR: tar backup failed"; exit 6; }

cd -