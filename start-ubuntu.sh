#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# CONFIGURATION
###############################################################################
PORT=14142
PROFILE="Bitcoin-Mainnet-Local-Dev"

# relative paths (from repo root)
LIGHTNING_REL_PATH="BTCPayServer.Lightning"
PLUGIN_REL_PATH="btcpayserver-plugin-template/BTCPayServer.Plugins.LSPS1"
BTCPAY_CSPROJ_REL_PATH="btcpayserver/BTCPayServer/BTCPayServer.csproj"
NBX_COOKIE_REL_PATH="btcpayserver-docker/data/nbxplorer_datadir/Main/.cookie"

###############################################################################
# 0.  Kill anything still bound to $PORT (gracefully, then force if needed)
###############################################################################
if lsof -i :"${PORT}" -sTCP:LISTEN -t >/dev/null 2>&1 \
  || ss -ltn "( sport = :${PORT} )" | tail -n +2 | grep -q LISTEN; then
  echo "🔄  BTCPay already running on :${PORT} – stopping it …"
  pkill -f 'dotnet.*BTCPayServer' || true
  sleep 2
  (lsof -ti :"${PORT}" -sTCP:LISTEN \
     || ss -ltnp "( sport = :${PORT} )" | awk '{print $NF}' | grep -oP '[0-9]+') \
       | xargs -r kill -9 || true
fi

###############################################################################
# 1.  Resolve repo paths & build libraries
###############################################################################
script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
repo_root="$(readlink -f "${script_dir}/..")"

# Build Lightning library first
echo "🔨  Building Lightning library …"
pushd "${repo_root}/${LIGHTNING_REL_PATH}" >/dev/null
dotnet build -c Debug
popd >/dev/null

# Then build the LSPS1 plugin
echo "🔨  Building LSPS1 plugin …"
pushd "${repo_root}/${PLUGIN_REL_PATH}" >/dev/null
dotnet build -c Debug
popd >/dev/null

###############################################################################
# 2.  Wait for NBXplorer cookie and export it
###############################################################################
COOKIE="${repo_root}/${NBX_COOKIE_REL_PATH}"
until [ -f "$COOKIE" ]; do
  echo "⏳  Waiting for NBXplorer cookie …"
  sleep 2
done
export BTCPAY_BTCEXPLORERCOOKIEFILE="$COOKIE"
echo "📄  NBX cookie: $BTCPAY_BTCEXPLORERCOOKIEFILE"

###############################################################################
# 3.  Launch BTCPay (Mainnet, local dev profile)
###############################################################################
echo "🚀  Starting BTCPay with profile: ${PROFILE}"
exec dotnet run \
  --project "${repo_root}/${BTCPAY_CSPROJ_REL_PATH}" \
  --launch-profile "${PROFILE}"