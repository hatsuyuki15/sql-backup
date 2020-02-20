#! /bin/bash

echo "> Backup users, grants, views, triggers, routines"
BACKUP_CONFIG_ENVFILE=env/mysql.env ./backup.sh

echo "> Backup schemas"
BACKUP_CONFIG_ENVFILE=env/structure.env ./backup.sh

echo "> Backup data"
BACKUP_CONFIG_ENVFILE=env/data.env ./backup.sh
