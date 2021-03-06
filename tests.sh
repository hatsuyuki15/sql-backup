#!/bin/bash
# Error codes
# 200 = Empty Variable
# 201 = Value is not a file
# 202 = Value is not a directory
# 203 = Missing dependency
# 204 = Databases listing failed
# 205 = Views listing failed
# 206 = No databases to backup
# 207 = Structure dump failed
# 208 = Data dump failed
# 209 = Routines dump failed
# 210 = Triggers dump failed
# 211 = Events dump failed
# 212 = Views dump failed
# 213 = Users dump failed
# 214 = Grants dump failed
# 215 = Grants list failed

TEST_MYSQL_HOST="${TEST_MYSQL_HOST:-localhost}"
TEST_MYSQL_USER="${TEST_MYSQL_USER:-root}"
TEST_MYSQL_PASS="${TEST_MYSQL_PASS:-}"
TEST_MYSQL_PORT="${TEST_MYSQL_PORT:-3306}"
SCRIPT_ROOT="$(dirname $0)"
echo "SCRIPT_ROOT=${SCRIPT_ROOT}"
MYSQLCREDS="${MYSQLCREDS:---host ${TEST_MYSQL_HOST} -u${TEST_MYSQL_USER} -p${TEST_MYSQL_PASS} --port ${TEST_MYSQL_PORT}}"

compareFiles() {
  compareFilesOrExit "${SCRIPT_ROOT}/samples/$1/structure.sql" "${SCRIPT_ROOT}/test/structure.sql"
  compareFilesOrExit "${SCRIPT_ROOT}/samples/$1/database.sql" "${SCRIPT_ROOT}/test/database.sql"
  compareFilesOrExit "${SCRIPT_ROOT}/samples/$1/grants.sql" "${SCRIPT_ROOT}/test/grants.sql"
  compareFilesOrExit "${SCRIPT_ROOT}/samples/$1/users.sql" "${SCRIPT_ROOT}/test/users.sql"
  compareFilesOrExit "${SCRIPT_ROOT}/samples/$1/events.sql" "${SCRIPT_ROOT}/test/events.sql"
  compareFilesOrExit "${SCRIPT_ROOT}/samples/$1/views.sql" "${SCRIPT_ROOT}/test/views.sql"
  compareFilesOrExit "${SCRIPT_ROOT}/samples/$1/triggers.sql" "${SCRIPT_ROOT}/test/triggers.sql"
  compareFilesOrExit "${SCRIPT_ROOT}/samples/$1/routines.sql" "${SCRIPT_ROOT}/test/routines.sql"
}

sourceCopy() {
  sed -n "/^$1()/,/^}/p" ./backup.sh > func.sh; source func.sh; rm func.sh
}

compareFilesSUM() {

  chk1="$(sha1sum $1 | awk -F" " '{print $1}')"
  chk2="$(sha1sum $2 | awk -F" " '{print $1}')"

  if [ "$chk1" = "$chk2" ]; then
    return 0
  else
    return 1
  fi

}

compareFilesOrExit() {
  diff -ia --unified=1 --suppress-common-lines "$1" "$2"
  compareFilesSUM "$@" || fail "Files are not identical ($1) ($2)"
}

testEMPTY_VAR_Fail() {
  ./backup.sh 1>/dev/null 2>&1
  assertEquals 200 "$?"
}

testBACKUP_CONFIG_ENVFILE_Fail() {
  export BACKUP_CONFIG_ENVFILE="/home/myuser/secretbackupconfig.env.txt"
  ./backup.sh
  assertEquals 201 "$?"
  unset BACKUP_CONFIG_ENVFILE
}

fillConfigFile() {
  echo "MYSQL_HOST=${TEST_MYSQL_HOST}" >> $1
  echo "MYSQL_USER=${TEST_MYSQL_USER}" >> $1
  echo "MYSQL_PASS=${TEST_MYSQL_PASS}" >> $1
  echo "MYSQL_PORT=${TEST_MYSQL_PORT}" >> $1
  echo "SKIP_DATABASES=mysql,sys,information_schema,performance_schema" >> $1
}

createTestData() {
  mysql ${MYSQLCREDS} < ${SCRIPT_ROOT}/samples/$1/create.sql
}

destroyTestData() {
  mysql ${MYSQLCREDS} < ${SCRIPT_ROOT}/samples/$1/destroy.sql
}

preTest() {
  mkdir ./test
  touch ./test/envfile
  echo "BACKUP_DIR=${SCRIPT_ROOT}/test" > ./test/envfile
  fillConfigFile ./test/envfile
  export BACKUP_CONFIG_ENVFILE="./test/envfile"
}

postTest() {
  rm ./test/*
  rmdir ./test
  unset BACKUP_CONFIG_ENVFILE
}

testBACKUP_CONFIG_ENVFILE_Success() {
  preTest
  echo "MYSQL_HOST=tests.test" >> "./test/envfile"
  ./backup.sh
  assertEquals 204 "$?"
  postTest
}

testBACKUP_EMPTY_Success() {
  preTest
  ./backup.sh
  assertEquals 206 "$?"
  postTest
}

testBACKUP_Success_NoDiff() {
  preTest
  createTestData "empty"
  ./backup.sh
  assertEquals 0 "$?"
  destroyTestData "empty"
  compareFiles "empty"
  postTest
}

testBACKUP_Success() {
  preTest
  createTestData "empty"
  ./backup.sh
  assertEquals 0 "$?"
  destroyTestData "empty"
  postTest
}

testOnSuccessScript() {
  preTest
  echo 'ON_SUCCESS="./postTest.sh"' >> "./test/envfile"
  createTestData "empty"
  ./backup.sh
  cat ./test/endfile > /dev/null
  assertEquals 0 "$?"
  destroyTestData "empty"
  postTest
}

testCompareFail() {
  # Expected fail
  compareFilesSUM "${SCRIPT_ROOT}/.gitignore" "${SCRIPT_ROOT}/samples/empty/events.sql"
  assertEquals 1 "$?"
}

testBACKUP_Success_NoDiff_Strange_BS_Data0() {
  preTest
  createTestData "withdata0"
  ./backup.sh
  assertEquals 0 "$?"
  destroyTestData "withdata0"
  compareFiles "withdata0"
  postTest
}

testBACKUP_Success_NoDiff_Strange_BS_Data1() {
  preTest
  createTestData "withdata1"
  ./backup.sh
  assertEquals 0 "$?"
  destroyTestData "withdata1"
  compareFiles "withdata1"
  postTest
}

testBACKUP_Success_NoDiff_Strange_BS_Data2() {
  preTest
  createTestData "withdata2"
  ./backup.sh
  assertEquals 0 "$?"
  destroyTestData "withdata2"
  compareFiles "withdata2"
  postTest
}

testBACKUP_Success_NoDatabases() {
  preTest
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/createuser.sql"
  echo "MYSQL_USER=grantfail" >> "./test/envfile"
  ./backup.sh
  assertEquals 206 "$?"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/deleteuser.sql"
  postTest
}

testEvents_NoData_Fail() {
  preTest
  createTestData "withdata0"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/createuser.sql"
  mysql ${MYSQLCREDS} -ANe "GRANT SELECT ON testbench.* TO 'grantfail'@'%';"
  echo "MYSQL_USER=grantfail" >> "./test/envfile"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToUsers.sql"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToDB.sql"
  ./backup.sh
  assertEquals 211 "$?"
  destroyTestData "withdata0"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/deleteuser.sql"
  postTest
}

testViewsDump_Fail() {
  preTest
  createTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/createuser.sql"
  mysql ${MYSQLCREDS} -ANe "GRANT INSERT ON testbench.* TO 'grantfail'@'%';"
  echo "MYSQL_USER=grantfail" >> "./test/envfile"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToUsers.sql"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToDB.sql"
  echo "SKIP_OP=structure,data,routines,events,triggers,users,grants" >> "./test/envfile"
  ./backup.sh
  assertEquals 212 "$?"
  destroyTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/deleteuser.sql"
  postTest
}

testUsers_Fail() {
  preTest
  createTestData "withdata0"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/createuser.sql"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToTestBench.sql"
  echo "MYSQL_USER=grantfail" >> "./test/envfile"
  ./backup.sh
  assertEquals 213 "$?"
  destroyTestData "withdata0"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/deleteuser.sql"
  postTest
}

testEvents_Fail() {
  preTest
  createTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/createuser.sql"
  mysql ${MYSQLCREDS} -ANe "GRANT SELECT, TRIGGER, SHOW VIEW ON testbench.* TO 'grantfail'@'%';"
  echo "MYSQL_USER=grantfail" >> "./test/envfile"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToUsers.sql"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToDB.sql"
  ./backup.sh
  assertEquals 211 "$?"
  destroyTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/deleteuser.sql"
  postTest
}

testStructure_Fail() {
  preTest
  createTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/createuser.sql"
  mysql ${MYSQLCREDS} -ANe "GRANT INSERT, TRIGGER, SHOW VIEW ON testbench.* TO 'grantfail'@'%';"
  echo "MYSQL_USER=grantfail" >> "./test/envfile"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToUsers.sql"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToDB.sql"
  ./backup.sh
  assertEquals 207 "$?"
  destroyTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/deleteuser.sql"
  postTest
}

testSkip_HasNot() {
  export SKIP_OP=()
  sourceCopy "hasSkip"
  hasSkip "t"
  assertEquals 0 "$?"
  unset SKIP_OP
}

testSkip_Has() {
  export SKIP_OP=("skip1")
  sourceCopy "hasSkip"
  hasSkip "skip1"
  assertEquals 1 "$?"
  unset SKIP_OP
}

testData_Fail() {
  preTest
  createTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/createuser.sql"
  mysql ${MYSQLCREDS} -ANe "GRANT INSERT ON testbench.* TO 'grantfail'@'%';"
  echo "MYSQL_USER=grantfail" >> "./test/envfile"
  echo "SKIP_OP=structure,routines,triggers,events,views,users,grants" >> "./test/envfile"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToUsers.sql"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToDB.sql"
  ./backup.sh
  assertEquals 208 "$?"
  destroyTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/deleteuser.sql"
  postTest
}

testRoutines_Fail() {
  preTest
  createTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/createuser.sql"
  mysql ${MYSQLCREDS} -ANe "GRANT INSERT ON testbench.* TO 'grantfail'@'%';"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/withdata2/function1.sql"
  echo "MYSQL_USER=grantfail" >> "./test/envfile"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToUsers.sql"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToDB.sql"
  echo "SKIP_OP=structure,data,triggers,events,views,users,grants" >> "./test/envfile"
  ./backup.sh
  assertEquals 209 "$?"
  destroyTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/deleteuser.sql"
  postTest
}

testTriggers_Fail() {
  preTest
  createTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/createuser.sql"
  mysql ${MYSQLCREDS} -ANe "GRANT INSERT ON testbench.* TO 'grantfail'@'%';"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/withdata2/trigger1.sql"
  echo "MYSQL_USER=grantfail" >> "./test/envfile"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToUsers.sql"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToDB.sql"
  echo "SKIP_OP=structure,data,routines,events,views,users,grants" >> "./test/envfile"
  ./backup.sh
  assertEquals 210 "$?"
  destroyTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/deleteuser.sql"
  postTest
}

testGrantsList_Fail() {
  preTest
  createTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/withdata2/createuser.sql"
  mysql ${MYSQLCREDS} -ANe "GRANT INSERT ON testbench.* TO 'userwd2gf'@'%';"
  echo "MYSQL_USER=userwd2gf" >> "./test/envfile"
  echo "SKIP_OP=structure,data,routines,events,triggers,users,views" >> "./test/envfile"
  ./backup.sh
  assertEquals 215 "$?"
  destroyTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/withdata2/deleteuser.sql"
  postTest
}

#testGrants_Fail() {
#  preTest
#  createTestData "withdata2"
#  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/withdata2/createuser.sql"
#  mysql ${MYSQLCREDS} -ANe "GRANT INSERT ON testbench.* TO 'userwd2gf'@'%';"
#  echo "MYSQL_USER=userwd2gf" >> "./test/envfile"
#  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/withdata2/grantToUsers.sql"
#  echo "SKIP_OP=structure,data,routines,events,triggers,users,views" >> "./test/envfile"
#  ./backup.sh
#  assertEquals 214 "$?"
#  destroyTestData "withdata2"
#  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/withdata2/deleteuser.sql"
#  postTest
#}

testBACKUP_manualgrant_Success() {
  preTest
  createTestData "withdata0"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/createuser.sql"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToTestBench.sql"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToUsers.sql"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToDB.sql"
  mysql ${MYSQLCREDS} -ANe "GRANT ALL PRIVILEGES ON mysql.* TO 'grantfail'@'%';"
  echo "MYSQL_USER=grantfail" >> "./test/envfile"
  ./backup.sh
  assertEquals 0 "$?"
  destroyTestData "withdata0"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/deleteuser.sql"
  postTest
}

testNoSkipDatabases() {
  preTest
  createTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/createuser.sql"
  mysql ${MYSQLCREDS} -ANe "GRANT INSERT ON testbench.* TO 'grantfail'@'%';"
  echo "MYSQL_USER=grantfail" >> "./test/envfile"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToUsers.sql"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/grantToDB.sql"
  echo "SKIP_OP=structure,data,routines,events,triggers,users,grants" >> "./test/envfile"
  echo "SKIP_DATABASES=" >> "./test/envfile"
  ./backup.sh
  assertEquals 0 "$?"
  destroyTestData "withdata2"
  mysql ${MYSQLCREDS} < "${SCRIPT_ROOT}/samples/empty/deleteuser.sql"
  postTest
}
export SHUNIT_COLOR="none" # GitHub actions
. ./shunit2-2.1.7/shunit2