# socgen-ofh-onboarding

Repository for onboarding SocGen's [OFH](https://forum.makerdao.com/t/security-tokens-refinancing-mip6-application-for-ofh-tokens/10605/8) to MCD. Forked and adapted from [MIP21-RWA-Example](https://github.com/makerdao/MIP21-RWA-Example) template repo.

## Dev

### Clone the repo

(Optional) You can run `nix-env -f https://github.com/dapphub/dapptools/archive/master.tar.gz -iA solc-static-versions.solc_0_6_12` for a lasting installation of the solidity version used.

### Install lib dependencies

```bash
make update
```

### Create local .env file & edit placeholder values

```bash
cp .env.exaples .env
```

### Build contracts

```bash
make build
```

### Test contracts

```bash
make test-local # using a local node listening on http://localhost:8545
make test-remote # using a remote node (alchemy). Requires ALCHEMY_API_KEY env var.
```

### Deploy contracts

```bash
make deploy-ces-goerli # to deploy contracts for the CES Fork of Goerli MCD
make deploy-goerli # to deploy contracts for the official Goerli MCD
make deploy-mainnet # to deploy contracts for the official Mainnet MCD
```

This script outputs a JSON file like this one:

```json
{
  "RWA_OFH_TOKEN": "<address>",
  "ILK": "RWA007-A",
  "MIP21_LIQUIDATION_ORACLE_2": "<address>",
  "RWA007": "<address>",
  "MCD_JOIN_RWA007_A": "<address>",
  "RWA007_A_URN": "<address>",
  "RWA007_A_INPUT_CONDUIT": "<address>",
  "RWA007_A_OUTPUT_CONDUIT": "<address>",
  "RWA007_A_OPERATOR": "<address>",
  "RWA007_A_MATE": "<address>"
}
```

You can save it using `stdout` redirection:

```bash
make deploy-ces-goerli > out/ces-goerli-addresses.json
```

### Verify source code

If you saved the deployed addresses like suggested above, in order to verify the contracts you need to extract the contents of the JSON file into environment variables. There is a convenience script for that in `scripts/json-to-env.sh`.

```bash
 # sets the proper env vars
source <(scripts/json-to-env.sh out/ces-goerli-addresses.json)
make verify-ces-goerli
```

### More...

You can also refer to the Makefile (`make <command>`) for full list of commands.

## License

AGPL-3.0 LICENSE
