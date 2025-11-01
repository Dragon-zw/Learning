#!/bin/bash

set -e

usage() {
    cat <<EOF
Generate self-signed certificate for webhook service.

usage: ${0} [OPTIONS]

The following flags are optional.

       --service          Service name of webhook (default: admission-webhook-example-svc)
       --namespace        Namespace where webhook service and secret reside (default: default)
       --secret           Secret name for CA certificate and server certificate/key pair (default: admission-webhook-example-certs)
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case ${1} in
        --service)
            service="$2"
            shift
            ;;
        --secret)
            secret="$2"
            shift
            ;;
        --namespace)
            namespace="$2"
            shift
            ;;
        *)
            usage
            ;;
    esac
    shift
done

[ -z ${service} ] && service=admission-webhook-example-svc
[ -z ${secret} ] && secret=admission-webhook-example-certs
[ -z ${namespace} ] && namespace=default

if [ ! -x "$(command -v openssl)" ]; then
    echo "openssl not found"
    exit 1
fi

tmpdir=$(mktemp -d)
echo "Creating certs in tmpdir ${tmpdir}"

# Generate CA key and certificate
openssl genrsa -out ${tmpdir}/ca-key.pem 2048
openssl req -x509 -new -nodes -key ${tmpdir}/ca-key.pem -days 365 -out ${tmpdir}/ca-cert.pem -subj "/CN=admission-webhook-ca"

# Create server certificate config
cat <<EOF > ${tmpdir}/server.conf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${service}
DNS.2 = ${service}.${namespace}
DNS.3 = ${service}.${namespace}.svc
DNS.4 = ${service}.${namespace}.svc.cluster.local
EOF

# Generate server key and CSR
openssl genrsa -out ${tmpdir}/server-key.pem 2048
openssl req -new -key ${tmpdir}/server-key.pem -out ${tmpdir}/server.csr -subj "/CN=${service}.${namespace}.svc" -config ${tmpdir}/server.conf

# Sign server certificate with CA
openssl x509 -req -in ${tmpdir}/server.csr -CA ${tmpdir}/ca-cert.pem -CAkey ${tmpdir}/ca-key.pem -CAcreateserial -out ${tmpdir}/server-cert.pem -days 365 -extensions v3_req -extfile ${tmpdir}/server.conf

echo "Certificates created successfully"

# Delete existing secret if it exists
kubectl delete secret ${secret} -n ${namespace} 2>/dev/null || true

# Create the secret with CA cert and server cert/key
kubectl create secret generic ${secret} \
    --from-file=key.pem=${tmpdir}/server-key.pem \
    --from-file=cert.pem=${tmpdir}/server-cert.pem \
    -n ${namespace}

echo "Secret ${secret} created in namespace ${namespace}"

# Output the CA bundle for webhook configuration
echo ""
echo "CA Bundle (base64 encoded) for webhook configuration:"
cat ${tmpdir}/ca-cert.pem | base64 | tr -d '\n'
echo ""

# Clean up
rm -rf ${tmpdir}
