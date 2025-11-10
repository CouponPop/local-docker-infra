#!/bin/bash

echo "=== MySQL Replication 초기화 시작 ==="
source .env
export MYSQL_PWD=$DB_ROOT_PASSWORD

echo "1. Master에서 replication 사용자 생성..."
mysql -h 127.0.0.1 -P $DB_MASTER_PORT -u root <<EOF
CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED WITH mysql_native_password BY '${DB_ROOT_PASSWORD}';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
EOF

echo "2. Slave에서 replication 설정 초기화..."
mysql -h 127.0.0.1 -P $DB_SLAVE_PORT -u root <<EOF
STOP REPLICA;
RESET REPLICA ALL;
RESET MASTER;

CHANGE REPLICATION SOURCE TO
    SOURCE_HOST='couponpop-mysql-master',
    SOURCE_PORT=3306,
    SOURCE_USER='repl',
    SOURCE_PASSWORD='${DB_ROOT_PASSWORD}',
    SOURCE_AUTO_POSITION = 1,
    GET_SOURCE_PUBLIC_KEY=1;

START REPLICA;
EOF

echo "3. Slave 상태 확인..."
REPLICA_STATUS=$(mysql -h 127.0.0.1 -P $DB_SLAVE_PORT -u root <<EOF
SHOW REPLICA STATUS\G
EOF
)

echo "$REPLICA_STATUS" | awk '
/Replica_IO_State:/ {io_state=$0}
/Source_Host:/ {source_host=$2}
/Replica_IO_Running:/ {io_running=$2}
/Replica_SQL_Running:/ {sql_running=$2}
/Auto_Position:/ {auto_pos=$2}
END {
    print "=== MySQL Replication Status ==="
    print io_state
    print "Source_Host:          ", source_host
    print "Replica_IO_Running:   ", io_running
    print "Replica_SQL_Running:  ", sql_running
    print "Auto_Position:        ", auto_pos
}'

echo "=== MySQL Replication 초기화 완료 ==="

unset MYSQL_PWD
