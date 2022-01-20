#!/bin/bash

set -eo pipefail

source "${BASH_SOURCE%/*}/common.sh"


[[ "$ETH_RPC_URL" && "$(seth chain)" == "$1" ]] || die "Please set a $1 ETH_RPC_URL"

# shellcheck disable=SC1091
source "${BASH_SOURCE%/*}/build-env-addresses.sh" ces-goerli >/dev/null 2>&1

export ETH_GAS=6000000

if [ -z "$MIP21_LIQUIDATION_ORACLE" ]; then
    [ ! -z "$MIP21_LIQUIDATION_ORACLE_INIT_VAL" ] || die "Please set MIP21_LIQUIDATION_ORACLE_INIT_VAL param"
    [ ! -z "$MIP21_LIQUIDATION_ORACLE_INIT_DOC" ] || die "Please set MIP21_LIQUIDATION_ORACLE_INIT_DOC param"
    [ ! -z "$MIP21_LIQUIDATION_ORACLE_INIT_TAU" ] || die "Please set MIP21_LIQUIDATION_ORACLE_INIT_TAU param"
fi

# TODO: confirm if name/symbol is going to follow the RWA convention
# TODO: confirm with DAO at the time of mainnet deployment if OFH will indeed be 007
[[ -z "$NAME" ]] && NAME="RWA-007"
[[ -z "$SYMBOL" ]] && SYMBOL="RWA007"
#
# WARNING (2021-09-08): The system cannot currently accomodate any LETTER beyond
# "A".  To add more letters, we will need to update the PIP naming convention
# to include the letter.  Unfortunately, while fixing this on-chain and in our
# code would be easy, RWA001 integrations may already be using the old PIP
# naming convention.  So, before we can have new letters we must:
# 1. Change the existing PIP naming convention
# 2. Change all the places that depend on that convention (this script included)
# 3. Make sure all integrations are ready to accomodate that new PIP name.
# ! TODO: check with team/PE if this is still the case
#
[[ -z "$LETTER" ]] && LETTER="A"

# [[ -z "$MIP21_LIQUIDATION_ORACLE" ]] && MIP21_LIQUIDATION_ORACLE="0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF"
# TODO: confirm liquidations handling - no liquidations for the time being

ZERO_ADDRESS="0x0000000000000000000000000000000000000000"

# goerli only, trust a couple of addresses
TRUST1="0x597084d145e96Ae2e89E1c9d8DEE6d43d3557898"
TRUST2="0xCB84430E410Df2dbDE0dF04Cf7711E656C90BDa2"

ILK="${SYMBOL}-${LETTER}"
ILK_ENCODED=$(seth --to-bytes32 "$(seth --from-ascii "$ILK")")

# build it
make build

[[ -z "$OPERATOR" ]] && OPERATOR=$(dapp create ForwardProxy "$ZERO_ADDRESS") # using generic forward proxy for goerli
[[ -z "$MATE" ]] && MATE=$(dapp create ForwardProxy "$ZERO_ADDRESS")         # using generic forward proxy for goerli

[[ -z "$RWA_OFH_TOKEN" ]] && {
    [[ -z "$RWA_OFH_TOKEN_SUPPLY" ]] && RWA_OFH_TOKEN_SUPPLY=400
    RWA_OFH_TOKEN=$(dapp create MockOFH "$RWA_OFH_TOKEN_SUPPLY")
    # Transfers the total supply to the operator's account
    seth send "$RWA_OFH_TOKEN" 'transfer(address,uint256)' "$OPERATOR" "$RWA_OFH_TOKEN_SUPPLY"
}


# tokenize it
[[ -z "$RWA_WRAPPER_TOKEN" ]] && RWA_WRAPPER_TOKEN=$(dapp create TokenWrapper "$RWA_OFH_TOKEN")

# route it
[[ -z "$RWA_OUTPUT_CONDUIT" ]] && {
    RWA_OUTPUT_CONDUIT=$(dapp create RwaOutputConduit "$MCD_DAI")

    # trust addresses for goerli
    seth send "$RWA_OUTPUT_CONDUIT" 'hope(address)' "$OPERATOR"
    seth send "$RWA_OUTPUT_CONDUIT" 'mate(address)' "$MATE"

    seth send "$RWA_OUTPUT_CONDUIT" 'rely(address)' "$MCD_PAUSE_PROXY"
    seth send "$RWA_OUTPUT_CONDUIT" 'deny(address)' "$ETH_FROM"
}

# join it
RWA_JOIN=$(dapp create AuthGemJoin "$MCD_VAT" "$ILK_ENCODED" "$RWA_WRAPPER_TOKEN")
seth send "$RWA_JOIN" 'rely(address)' "$MCD_PAUSE_PROXY"

# urn it
RWA_URN=$(dapp create RwaUrn "$MCD_VAT" "$MCD_JUG" "$RWA_JOIN" "$MCD_JOIN_DAI" "$RWA_OUTPUT_CONDUIT")
seth send "$RWA_URN" 'rely(address)' "$MCD_PAUSE_PROXY"
seth send "$RWA_URN" 'deny(address)' "$ETH_FROM"

# rely it
seth send "$RWA_JOIN" 'rely(address)' "$RWA_URN"
# deny it
seth send "$RWA_JOIN" 'deny(address)' "$ETH_FROM"

# connect it
[[ -z "$RWA_INPUT_CONDUIT" ]] && {
    RWA_INPUT_CONDUIT=$(dapp create RwaInputConduit "$MCD_DAI" "$RWA_URN")

    # trust addresses for goerli
    seth send "$RWA_INPUT_CONDUIT" 'mate(address)' "$MATE"

    seth send "$RWA_INPUT_CONDUIT" 'rely(address)' "$MCD_PAUSE_PROXY"
    seth send "$RWA_INPUT_CONDUIT" 'deny(address)' "$ETH_FROM"
}

# price it
[[ -z "$MIP21_LIQUIDATION_ORACLE" ]] && {
    MIP21_LIQUIDATION_ORACLE=$(dapp create RwaLiquidationOracle "$MCD_VAT" "$MCD_VOW")

    seth send "$MIP21_LIQUIDATION_ORACLE" 'init(bytes32,uint256,string,uint48)' \
        "$ILK_ENCODED" \
        "$MIP21_LIQUIDATION_ORACLE_INIT_VAL" \
        "$MIP21_LIQUIDATION_ORACLE_INIT_DOC" \
        "$MIP21_LIQUIDATION_ORACLE_INIT_TAU"

    seth send "$MIP21_LIQUIDATION_ORACLE" 'rely(address)' "$MCD_PAUSE_PROXY"
    seth send "$MIP21_LIQUIDATION_ORACLE" 'deny(address)' "$ETH_FROM"
}

# print it
echo "OPERATOR: ${OPERATOR}"
echo "MATE: ${MATE}"
# echo "TRUST1: ${TRUST1}"
# echo "TRUST2: ${TRUST2}"
echo "ILK: ${ILK}"
echo "${SYMBOL}: ${RWA_WRAPPER_TOKEN}"
echo "MCD_JOIN_${SYMBOL}_${LETTER}: ${RWA_JOIN}"
echo "${SYMBOL}_${LETTER}_URN: ${RWA_URN}"
echo "${SYMBOL}_${LETTER}_INPUT_CONDUIT: ${RWA_INPUT_CONDUIT}"
echo "${SYMBOL}_${LETTER}_OUTPUT_CONDUIT: ${RWA_OUTPUT_CONDUIT}"
echo "MIP21_LIQUIDATION_ORACLE: ${MIP21_LIQUIDATION_ORACLE}"
