#!/bin/bash
# Railway start script for Nacos (standalone + MySQL). Fails fast with a non-zero exit so Railway restarts it.
set -euo pipefail

: "${NACOS_AUTH_TOKEN:?NACOS_AUTH_TOKEN must be set (Base64, at least 32 bytes)}"
: "${NACOS_AUTH_IDENTITY_KEY:?NACOS_AUTH_IDENTITY_KEY must be set}"
: "${NACOS_AUTH_IDENTITY_VALUE:?NACOS_AUTH_IDENTITY_VALUE must be set}"
: "${NACOS_ADMIN_PASSWORD:?NACOS_ADMIN_PASSWORD must be set}"
: "${MYSQL_SERVICE_HOST:?MYSQL_SERVICE_HOST must be set (reference your MySQL service)}"
: "${MYSQL_SERVICE_DB_NAME:?MYSQL_SERVICE_DB_NAME must be set}"
: "${MYSQL_SERVICE_USER:?MYSQL_SERVICE_USER must be set}"
: "${MYSQL_SERVICE_PASSWORD:?MYSQL_SERVICE_PASSWORD must be set}"

export MODE=standalone
export SPRING_DATASOURCE_PLATFORM=mysql
export MYSQL_SERVICE_PORT="${MYSQL_SERVICE_PORT:-3306}"
export MYSQL_SERVICE_DB_PARAM="${MYSQL_SERVICE_DB_PARAM:-characterEncoding=utf8&connectTimeout=10000&socketTimeout=30000&autoReconnect=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC}"
export PREFER_HOST_MODE="${PREFER_HOST_MODE:-hostname}"
# Web console listens on Railway's PORT; the client/API port stays 8848 (+1000 gRPC) on the private network.
export NACOS_CONSOLE_PORT="${PORT:-8080}"
export NACOS_APPLICATION_PORT="${NACOS_APPLICATION_PORT:-8848}"
export TIME_ZONE="${TIME_ZONE:-UTC}"
# Standalone Nacos keeps its embedded Raft groups (persistent naming data) under /home/nacos/data with the
# member address baked in. Railway gives the container a new IP on every deploy, which would orphan those
# groups ("did not find the Leader node"), so pin the single member to loopback.
export NACOS_SERVER_IP="${NACOS_SERVER_IP:-127.0.0.1}"

# Sized for a 1 GB Railway service (the image's own defaults are a 1 GB heap alone).
# Nacos needs about 600 MB RSS at idle (JVM + 5 embedded RocksDB/JRaft groups), so 0.5 GB is too small.
# Raise NACOS_JVM_XMX together with the service's RAM for real traffic.
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"
export JVM_XMS="${NACOS_JVM_XMS:-128m}"
export JVM_XMX="${NACOS_JVM_XMX:-256m}"
export JVM_XMN="${NACOS_JVM_XMN:-64m}"
export JAVA_OPT="${JAVA_OPT:-} -XX:+UseSerialGC -XX:MaxMetaspaceSize=${NACOS_JVM_MMS:-160m} -XX:ReservedCodeCacheSize=64m -Xss512k -XX:MaxDirectMemorySize=64m -XX:ActiveProcessorCount=${NACOS_JVM_CPUS:-2} -XX:TieredStopAtLevel=1 -XX:+ExitOnOutOfMemoryError -Duser.timezone=${TIME_ZONE}"

BASE=/home/nacos
CP="$BASE/railway:$BASE/plugins/mysql-connector-j-8.2.0.jar:$(ls $BASE/railway/spring-security-crypto-*.jar):$(ls $BASE/railway/commons-logging-*.jar)"
echo "[railway] preparing MySQL schema and admin account"
java -Xmx48m -XX:+UseSerialGC -cp "$CP" RailwayInit "$BASE/conf/mysql-schema.sql"

cd "$BASE"
exec bash "$BASE/bin/docker-startup.sh"
