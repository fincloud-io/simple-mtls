#!/usr/bin/env bash

THIS=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null||echo "$0")
ROOT=$(dirname "${THIS}")
TIMESTAMP=$(date "+%Y%m%d-%H%M%S")
INIFILE="$ROOT/certificates.ini"
SERVER_NAME="myserver"

if ! command -v gawk > /dev/null; then
  echo "This script requires gawk"
  exit 1
fi
if [ -f "$ROOT/parse_ini.sh" ]; then
  # shellcheck source=parse_ini.sh
  source "$ROOT/parse_ini.sh"
else
  echo "ERROR: Could not load library [$ROOT/parse_ini.sh]"
  exit 1
fi
if ! command -v openssl > /dev/null; then
  echo "This script requires openssl v1.1+"
  exit 1
fi
if ! command -v keytool > /dev/null; then
  echo "This script requires keytool. Ensure you have a JDK installed"
  exit 1
fi

# We can supply an alternative ini file
if [ "$#" -eq "1" ]; then
  INIFILE="$1"
fi

if [ -f "$INIFILE" ]; then
  GetINISections "$INIFILE"
else
  echo "Error opening file [$INIFILE]"
  exit 1
fi
# shellcheck disable=SC2154
if [ "${configuration_password["ca"]}" == "DEFAULT" ] || [ "${configuration_password["server"]}" == "DEFAULT" ]; then
  echo "ERROR: Please look at README.md, edit the ini file and don't use default passwords !!"
  exit 1
fi
if [ ${#configuration_password["ca"]}  -le 6 ] || [ ${#configuration_password["server"]} -le 6 ]; then
  echo "ERROR: Passwords must be longer than 6 characters !!"
  exit 1
fi

echo "Certificate generation assistant"
echo "INIT  : Check [$(openssl version)] - must be v1.1+ "
# shellcheck disable=SC2154
DIR=${configuration_ca["ShortName"]}
if [ -d "$DIR" ]; then
    echo "INIT  : Client [$DIR] already exists, backup and create new certificates."
    mv "$DIR" "$DIR-$TIMESTAMP"
fi

# shellcheck disable=SC2154
ROOT_CA_PASSWORD="${configuration_password["ca"]}"
# shellcheck disable=SC2154
INTERMEDIATE_CA_PASSWORD="${configuration_password["intermediate"]}"
# shellcheck disable=SC2154
SERVER_PASSWORD="${configuration_password["server"]}"


mkdir -p "$DIR/CA"
cat <<EOF > "$DIR/CA/root_ca.cnf"
[ req ]
default_bits = ${configuration_defaults["key_length"]}
#default_keyfile = $DIR/CA/rootCA.key
prompt = no
distinguished_name = req_distinguished_name
x509_extensions	= v3_ca

[ req_distinguished_name ]
C	= ${configuration_ca["CountryCode"]}
ST = ${configuration_ca["State"]}
L	= ${configuration_ca["Locality"]}
O	= ${configuration_ca["OrganisationName"]}
OU = ${configuration_ca["OrganisationalUnit"]}
CN = ${configuration_ca["Domain"]}
emailAddress	= ${configuration_ca["email"]}

[ v3_ca ]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer:always
basicConstraints = critical,CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF

echo "CA    : Generating a key for self-signed Root CA cert:.."
#openssl genrsa -des3 -passout file:"$DIR/CA/mypass.enc" -out "$DIR/CA/rootCA.key" "${configuration_defaults["key_length"]}"
# shellcheck disable=SC2154
if ! openssl genrsa -des3 -passout pass:"$ROOT_CA_PASSWORD" -out "$DIR/CA/rootCA.key" \
"${configuration_defaults["key_length"]}" >> /dev/null 2>&1; then
    echo "CA    : FAILED to generate a key for self-signed Root CA cert:.."
    exit 1
fi

echo "CA    : Generating a self-signed Root CA certificate"
if ! openssl req -x509 -sha256 -days "${configuration_ca["root_cert_valid_days"]}" -new -passin pass:"$ROOT_CA_PASSWORD" \
-key "$DIR/CA/rootCA.key" -config "$DIR/CA/root_ca.cnf" -out "$DIR/CA/rootCA.crt" >> /dev/null  2>&1; then
    echo "CA    : FAILED to generate a self-signed Root CA certificate"
    exit 1
fi


echo "CA    : Generating a key for self-signed Intermediate CA cert:.."
#openssl genrsa -des3 -passout file:"$DIR/CA/mypass.enc" -out "$DIR/CA/rootCA.key" "${configuration_defaults["key_length"]}"
# shellcheck disable=SC2154
if ! openssl genrsa -des3 -passout pass:"$INTERMEDIATE_CA_PASSWORD" -out "$DIR/CA/intermediateCA.key" \
"${configuration_defaults["key_length"]}" >> /dev/null 2>&1; then
    echo "CA    : FAILED to generate a key for self-signed Root CA cert:.."
    exit 1
fi

echo "CA    : Generating a self-signed Intermediate CA certificate"
if ! openssl req -x509 -sha256 -days "${configuration_ca["intermediate_cert_valid_days"]}" -new -passin pass:"$ROOT_CA_PASSWORD" \
-key "$DIR/CA/intermediateCA.key" -config "$DIR/CA/root_ca.cnf" -out "$DIR/CA/intermediateCA.crt" >> /dev/null  2>&1; then
    echo "CA    : FAILED to generate a self-signed Root CA certificate"
    exit 1
fi

rm "$DIR/CA/root_ca.cnf"

mkdir -p "$DIR/Server"
cat <<EOF > "$DIR/Server/server_csr.cnf"
[ req ]
default_bits = ${configuration_defaults["key_length"]}
default_keyfile = $DIR/Server/$SERVER_NAME.key
prompt = no
distinguished_name = req_distinguished_name
req_extensions	= v3_req
x509_extensions	= v3_req

[ req_distinguished_name ]
commonName = ${configuration_server["hostname"]}

[ v3_req ]
subjectAltName = @alt_names
subjectKeyIdentifier = hash
basicConstraints     = critical,CA:false
keyUsage             = critical,digitalSignature,keyEncipherment

[alt_names]
DNS.1 = ${configuration_server["hostname"]}
DNS.2 = ${configuration_server["additional_hostname"]}
EOF

SERVERHOST=${configuration_server["hostname"]}
HOSTCHECK="$(dig +noall +answer "$SERVERHOST" | wc -l)"
if [ ! "$HOSTCHECK" -gt 0 ]; then
  echo "TLS   : **WARNING** [$SERVERHOST] does not exist in DNS. TLS hostname verification could fail !"
else
  echo "TLS   : Checked that [$SERVERHOST] exists in DNS"
fi

echo "TLS   : Generating a key for server cert :.."
if ! openssl genrsa -des3 -passout pass:"$SERVER_PASSWORD" -out "$DIR/Server/$SERVER_NAME.key" \
"${configuration_defaults["key_length"]}" >> /dev/null 2>&1; then
    echo "CA    : FAILED to generate a key for server cert"
    exit 1
fi

echo "TLS   : Generating a CSR for the server cert"
if ! openssl req -new -out "$DIR/Server/$SERVER_NAME.csr" -config "$DIR/Server/server_csr.cnf"  \
-passout pass:"$SERVER_PASSWORD" >> /dev/null 2>&1; then
    echo "CA    : FAILED to generate a CSR for the server cert"
    exit 1
fi
rm "$DIR/Server/server_csr.cnf"


cat <<EOF > "$DIR/Server/server_cert_ext.cnf"
basicConstraints = CA:FALSE
nsCertType = server
nsComment = ${configuration_ca["OrganisationName"]} " - Client Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${configuration_server["hostname"]}
DNS.2 = ${configuration_server["additional_hostname"]}
EOF

echo "TLS   : Signing the server CSR with the intermediate CA and creating a server cert:"
if ! openssl x509 -req -CA "$DIR/CA/intermediateCA.crt" -CAkey "$DIR/CA/intermediateCA.key" -passin pass:"$INTERMEDIATE_CA_PASSWORD" \
-in "$DIR/Server/$SERVER_NAME.csr" -out "$DIR/Server/$SERVER_NAME.crt" -days "${configuration_server["cert_valid_days"]}" \
-CAcreateserial -extfile "$DIR/Server/server_cert_ext.cnf" >> /dev/null 2>&1; then
    echo "CA    : FAILED to sign the server CSR with the CA and create a server cert"
    exit 1
fi
rm "$DIR/Server/server_cert_ext.cnf"

echo "PKCS12: Exporting the server cert & key to .pfx file"
if ! openssl pkcs12 -export -out "$DIR/$SERVER_NAME.pfx" -inkey "$DIR/Server/$SERVER_NAME.key" \
-in "$DIR/Server/$SERVER_NAME.crt" -certfile "$DIR/CA/rootCA.crt" -certfile "$DIR/CA/intermediateCA.crt"  -name "tomcat" \
-passin pass:"$SERVER_PASSWORD" -passout pass:"$SERVER_PASSWORD" >> /dev/null 2>&1; then
    echo "CA    : FAILED to export the server cert & key to .pfx file"
    exit 1
fi


echo "TRUST : Creating a TrustStore and adding the rootCA"
# NB - Technically, by trusting the rootCA, we shouldn't need to put the intermediateCA in the chain as long as its sent with the client cert.
if ! keytool -import -trustcacerts -noprompt -alias ca -ext san=dns:localhost,ip:127.0.0.1 \
-file "$DIR/CA/rootCA.crt" -file "$DIR/CA/intermediateCA.crt" -keystore "$DIR/truststore.jks" -storepass "$SERVER_PASSWORD"  >> /dev/null 2>&1; then
    echo "CA    : FAILED to create a TrustStore"
    exit 1
fi

echo "DONE"