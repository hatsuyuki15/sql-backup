#! /bin/sh

#set -e

host=127.0.0.1
pass=pass

echo "> Remove users except 'root'"
echo "delete from user where User != 'root'" | mysql -uroot -p$pass -h$host --database mysql

echo "> Import users" 
mysql -uroot -p$pass -h$host --database mysql < ~/sql/users.sql

echo "> Flush privileges"
echo "FLUSH PRIVILEGES" | mysql -uroot -p$pass -h$host --database mysql 

echo "> Import schemas"
mysql -uroot -p$pass -h$host --database mysql < ~/sql/structure.sql

echo "> Import views"
mysql -f -uroot -p$pass -h$host --database mysql < ~/sql/views.sql

# Rerun because some views might depend on another views that has been not created at that point yet
echo "> Reimport views"
mysql -f -uroot -p$pass -h$host --database mysql < ~/sql/views.sql 

echo "> Import grants"
mysql -f -uroot -p$pass -h$host --database mysql < ~/sql/grants.sql

echo "> Import data"
pv ~/sql/database.sql | mysql -f -uroot -p$pass -h$host 
