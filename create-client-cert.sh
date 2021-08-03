#!/usr/bin/env bash

THIS=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null||echo "$0")
ROOT=$(dirname "${THIS}")
TIMESTAMP=$(date "+%Y%m%d-%H%M%S")
INIFILE="$ROOT/certificates.ini"

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
echo "INIT  : Check [$(openssl version)] - must be v1.1+ "
# We can supply an alternative ini file
if [ "$#" -eq "2" ]; then
  INIFILE="$2"
fi

if [ -f "$INIFILE" ]; then
  GetINISections "$INIFILE"
else
  echo "Error opening file [$INIFILE]"
  exit 1
fi

# shellcheck disable=SC2154
if [ ! -d "${configuration_ca["ShortName"]}" ]; then
  echo "ERROR: Please look at README.md, and run the create_server_cert.sh script first !!"
  exit 1
fi
# shellcheck disable=SC2154
DIR=${configuration_ca["ShortName"]}

if [ "$#" -ge "1" ]; then
  if [ -f "$1" ]; then
    csr="$1"
  else
    echo "CSR file [$1] does not exist"
    exit 1
  fi
else
  echo "Usage: $0 <CSR_file> [optional ini file]"
  exit 1
fi

# shellcheck disable=SC2154
CA_PASSWORD="${configuration_password["ca"]}"

echo "$TIMESTAMP: Creating TLS client certificate for [$DIR] from CSR [$csr].."
# shellcheck disable=SC2154
if ! openssl x509 -req -CA "$DIR/CA/rootCA.crt" -CAkey "$DIR/CA/rootCA.key" -in "$csr" -passin pass:"$CA_PASSWORD" \
-out "$DIR/client.crt" -days "${configuration_client["cert_valid_days"]}"; then
    echo "$TIMESTAMP: FAILED to create TLS client certificate"
    exit 1
fi
