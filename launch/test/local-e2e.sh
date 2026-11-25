#!/usr/bin/env bash
# The whole launch, rehearsed on a throwaway local Solana validator: the $GULL coin, the
# Fishers collection, the Candy Machine and a few public mints. Nothing touches devnet or
# mainnet. Needs the Solana CLI (solana-test-validator) and the three Metaplex program
# binaries in $PROGRAMS (see README: "Rehearse locally").
#
#   PROGRAMS=/path/to/programs bash test/local-e2e.sh [steps...]
#   steps: token upload collection candy mint check page wallet   (default: all of them)
set -euo pipefail
cd "$(dirname "$0")/.."
PROGRAMS="${PROGRAMS:-../programs}"
WORK="$(mktemp -d)"
export GULL_NETWORK=localnet
export GULL_KEYPAIR="$WORK/payer.json"
STEPS="${*:-token upload collection candy mint check page wallet}"
# a rehearsal loads the first 60 Fishers (GULL_ITEMS=3333 for the full set)

solana-keygen new --no-bip39-passphrase --silent -o "$GULL_KEYPAIR" >/dev/null
rm -f state/localnet.json state/localnet-uploads.json

solana-test-validator --reset --quiet --ledger "$WORK/ledger" \
  --bpf-program CoREENxT6tW1HoK8ypY1SxRMZTcVPm7R94rH4PZNhX7d "$PROGRAMS/mpl_core.so" \
  --bpf-program CMACYFENjoBMHzapRXyo1JZkVS6EtaDDzkjMrmQLvr4J "$PROGRAMS/mpl_core_candy_machine.so" \
  --bpf-program CMAGAKJ67e9hRZgfC5SFTbZH8MgEmtqazKXjmkaJjWTJ "$PROGRAMS/mpl_core_candy_guard.so" \
  > "$WORK/validator.log" 2>&1 &
VALIDATOR=$!
trap 'kill $VALIDATOR 2>/dev/null; wait $VALIDATOR 2>/dev/null; rm -rf "$WORK"' EXIT

for _ in $(seq 60); do solana -u localhost cluster-version >/dev/null 2>&1 && break; sleep 1; done
solana -u localhost airdrop 500 "$(solana-keygen pubkey "$GULL_KEYPAIR")" >/dev/null
echo "== local validator up, payer funded"

for step in $STEPS; do
  echo "== $step"
  case "$step" in
    token) node scripts/token.mjs ;;
    upload) GULL_ITEMS="${GULL_ITEMS:-60}" node scripts/nft-upload.mjs ;;
    collection) node scripts/nft-collection.mjs ;;
    candy) GULL_TEST_START_NOW=1 node scripts/nft-candy.mjs ;;
    mint) GULL_MINT_COUNT=3 node scripts/nft-mint.mjs ;;
    check) node test/check-local.mjs ;;
    page) node scripts/status.mjs >/dev/null && node mint-site/build.mjs >/dev/null && node test/mint-page.mjs ;;
    wallet) node test/game-wallet.mjs ;;
    run:*) node "${step#run:}" ;;
    *) echo "unknown step $step"; exit 2 ;;
  esac
done
echo "== LOCAL E2E PASSED: $STEPS"
