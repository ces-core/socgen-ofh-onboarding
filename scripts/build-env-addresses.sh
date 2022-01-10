#!/bin/bash
# build-env-addresses.sh

# Loads an address file from a URL and adds checksummed contract addresses to the environment
# Source this script to set envvars
#    `bash ./scripts/build-env-addresses.sh [ network ]`
# Run as script and write to file to save exports to source file
#    `bash ./scripts/build-env-addresses.sh [ network ] > env-addresses-network`

function validate_url() {
  if [[ $(curl -I ${1} 2>&1 | grep -E 'HTTP/(1.1|2) [23][0-9]+') ]]; then
    return 0
  else
    return 1
  fi
}

if [[ $_ != "${0}" ]]; then
  # Script was run as source
  SOURCED=1
fi

if [ -z "${1}" ]; then
  echo "Please specify the network [ mainnet, goerli ] or a file path as an argument."
  [ -z "${PS1}" ] && exit || return
fi

if [ "${1}" == "goerli" ]; then
  URL="https://changelog.makerdao.com/releases/goerli/active/contracts.json"
elif [ "${1}" == "mainnet" ]; then
  URL="https://changelog.makerdao.com/releases/mainnet/active/contracts.json"
else
  echo "# Invalid network ${1}"
  [ -z "${PS1}" ] && exit || return
fi

if validate_url "${URL}"; then
  echo "# Deployment addresses generated from:"
  echo "# ${URL}"
  ADDRESSES_RAW="$(curl -Ls "${URL}")"
else
  echo "# Invalid URL ${URL}"
  [ -z "${PS1}" ] && exit || return
fi

OUTPUT=$(jq -r 'to_entries | map(.key + "|" + (.value | tostring)) | .[]' <<<"${ADDRESSES_RAW}" | \
  while IFS='|' read -r key value; do
    PAIR="${key}=$(seth --to-checksum-address "${value}")"
    echo "${PAIR}"
  done
)

for pair in $OUTPUT
do
  if [[ $SOURCED == 1 ]]; then
    echo "${pair}"
    export "${pair?}"
  else
    echo "export ${pair}"
  fi
done