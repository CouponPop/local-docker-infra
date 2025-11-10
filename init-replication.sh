#!/bin/bash

echo "=== MySQL Replication 초기화 시작 ==="
# .env 로드
source .env
export MYSQL_PWD=$DB_ROOT_PASSWORD

# Replication User 생성
echo "1. Master에서 replication 사용자 생성..."
mysql -h 127.0.0.1 -P $DB_MASTER_PORT -u root <<EOF
CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED WITH mysql_native_password BY '${DB_ROOT_PASSWORD}';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
EOF

echo "2. Master의 바이너리 로그 위치 확인..."
MASTER_STATUS=$(mysql -h 127.0.0.1 -P $DB_MASTER_PORT -u root -e "SHOW MASTER STATUS\G")
echo "$MASTER_STATUS"

BINLOG_FILE=$(echo "$MASTER_STATUS" | grep "File:" | awk '{print $2}')
BINLOG_POS=$(echo "$MASTER_STATUS" | grep "Position:" | awk '{print $2}')

echo "Binary Log File: $BINLOG_FILE"
echo "Binary Log Position: $BINLOG_POS"

if [ -z "$BINLOG_FILE" ] || [ -z "$BINLOG_POS" ]; then
    echo "ERROR: Master 상태를 가져올 수 없습니다!"
    exit 1
fi

echo "3. Slave에서 replication 설정..."
mysql -h 127.0.0.1 -P $DB_SLAVE_PORT -u root <<EOF
STOP REPLICA;

-- 2) 마스터에서 확인한 File, Position 입력
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST='couponpop-mysql-master', -- master DB 서버의 호스트명 (IP)
    SOURCE_PORT=${DB_MASTER_PORT}, -- master DB 서버의 MySQL DB 포트
    SOURCE_LOG_FILE='${BINLOG_FILE}', -- master DB 상태 확인에서 확인한 File 부분
    SOURCE_LOG_POS=${BINLOG_POS}, -- master DB 상태 확인에서 확인한 Position 부분
    GET_SOURCE_PUBLIC_KEY=1;


-- 3) 복제 시작 시 계정 명시
START REPLICA USER ='repl' PASSWORD ='$DB_ROOT_PASSWORD';

START REPLICA;
EOF

echo "4. Slave 상태 확인..."
REPLICA_STATUS=$(mysql -h 127.0.0.1 -P $DB_SLAVE_PORT -u root <<EOF
SHOW REPLICA STATUS\G
EOF
)

# 원하는 필드만 추출
echo "$REPLICA_STATUS" | awk '
/Replica_IO_State:/ {io_state=$2}
/Source_Host:/ {source_host=$2}
/Replica_IO_Running:/ {io_running=$2}
/Replica_SQL_Running:/ {sql_running=$2}
/Source_Log_File:/ {log_file=$2}
/Source_Log_Pos:/ {log_pos=$2}
END {
    print "=== MySQL Replication Status ==="
    print "Replica_IO_State:     ", io_state
    print "Source_Host:          ", source_host
    print "Replica_IO_Running:   ", io_running
    print "Replica_SQL_Running:  ", sql_running
    print "Source_Log_File:      ", log_file
    print "Source_Log_Pos:       ", log_pos
}'

echo "=== MySQL Replication 초기화 완료 ==="

unset MYSQL_PWD