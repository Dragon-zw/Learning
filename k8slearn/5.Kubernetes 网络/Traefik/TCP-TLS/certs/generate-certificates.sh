#!/bin/bash
# Golang 1.17.1版本的发布不再支持go get命令 
# From https://medium.com/@rajanmaharjan/secure-your-mongodb-connections-ssl-tls-92e2addb3c89
# GitHub https://github.com/jsha/minica

set -eu -o pipefail

DOMAINS="${1}"
CERTS_DIR="${2}"
[ -d "${CERTS_DIR}" ]
CURRENT_DIR="$(cd "$(dirname "${0}")" && pwd -P)"

GENERATION_DIRNAME="$(echo "${DOMAINS}" | cut -d, -f1)"

rm -rf "${CERTS_DIR}/${GENERATION_DIRNAME:?}" "${CERTS_DIR}/certs"

echo "== Checking Requirements..."
command -v go >/dev/null 2>&1 || echo "Golang is required"
command -v minica >/dev/null 2>&1 || go install github.com/jsha/minica@latest >/dev/null 

# 获取 Go bin 目录路径
GOBIN=$(go env GOPATH)/bin
export PATH=$PATH:$GOBIN

echo "== Generating Certificates for the following domains: ${DOMAINS}..."
cd "${CERTS_DIR}"
"${GOBIN}/minica" --ca-cert "${CURRENT_DIR}/minica.pem" --ca-key="${CURRENT_DIR}/minica-key.pem" --domains="${DOMAINS}"
mv "${GENERATION_DIRNAME}" "certs"
cat certs/key.pem certs/cert.pem > certs/mongo.pem

echo "== Certificates Generated in the directory ${CERTS_DIR}/certs"

# 官方使用方式
# $ cd /ANY/PATH
# $ git clone https://github.com/jsha/minica.git
# $ go build |OR| $ go install