#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# CONFIGURATION
###############################################################################
PORT=14142
PROFILE="Bitcoin-Mainnet-Local-Dev"
PLUGIN_REL_PATH="btcpayserver-plugin-template/BTCPayServer.Plugins.LSPS1"
BTCPAY_CSPROJ_REL_PATH="btcpayserver/BTCPayServer/BTCPayServer.csproj"

###############################################################################
# 0.  Kill anything still bound to $PORT (gracefully, then force if needed)
###############################################################################
if lsof -i :"${PORT}" -sTCP:LISTEN -t >/dev/null 2>&1 \
   || ss -ltn "( sport = :${PORT} )" | tail -n +2 | grep -q LISTEN; then
  echo "🔄  BTCPay already running on :${PORT} – stopping it …"
  pkill -f 'dotnet.*BTCPayServer' || true
  sleep 2
  # kill whatever is still listening
  (lsof -ti :"${PORT}" -sTCP:LISTEN || ss -ltnp "( sport = :${PORT} )" \
     | awk '{print $NF}' | grep -oP '[0-9]+') \
       | xargs -r kill -9 || true
fi

###############################################################################
# 1.  Build LSPS1 plugin (Debug)
###############################################################################
echo "🔨  Building LSPS1 plugin …"
script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
repo_root="$(readlink -f "${script_dir}/..")"

pushd "${repo_root}/${PLUGIN_REL_PATH}" >/dev/null
dotnet build -c Debug
popd >/dev/null

###############################################################################
# 2.  Compute & export the NBXplorer cookie path
###############################################################################
cookie_path="${repo_root}/btcpayserver-docker/data/nbxplorer/.cookie"
export BTCPAY_BTCEXPLORERCOOKIEFILE="${cookie_path}"

echo "📄  Using NBX cookie: ${BTCPAY_BTCEXPLORERCOOKIEFILE}"

###############################################################################
# 3.  Launch BTCPay (Mainnet, local dev profile)
###############################################################################
echo "🚀  Starting BTCPay with profile: ${PROFILE}"
exec dotnet run \
    --project "${repo_root}/${BTCPAY_CSPROJ_REL_PATH}" \
    --launch-profile "${PROFILE}"