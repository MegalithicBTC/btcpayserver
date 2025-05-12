#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 0.  Kill anything still bound to :14142 (gracefully, then force if needed)
###############################################################################
if lsof -i :14142 -sTCP:LISTEN -t >/dev/null; then
  echo "🔄  BTCPay already running on :14142 – stopping it …"
  pkill -f 'dotnet.*BTCPayServer' || true
  sleep 2
  lsof -ti :14142 -sTCP:LISTEN | xargs -r kill -9 || true
fi

###############################################################################
# 1.  Build LSPS1 plugin (Debug)
###############################################################################
echo "🔨  Building LSPS1 plugin …"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

pushd "${repo_root}/btcpayserver-plugin-template/BTCPayServer.Plugins.LSPS1" >/dev/null
dotnet build -c Debug
popd >/dev/null

###############################################################################
# 2.  Compute & export the NBXplorer cookie path
###############################################################################
cookie_path="${repo_root}/btcpayserver-docker/data/nbxplorer/.cookie"
export BTCPAY_BTCEXPLORERCOOKIEFILE="$cookie_path"

echo "📄  Using NBX cookie: ${BTCPAY_BTCEXPLORERCOOKIEFILE}"

###############################################################################
# 3.  Launch BTCPay (Mainnet, local dev profile)
###############################################################################
echo "🚀  Starting BTCPay with profile: Bitcoin-Mainnet-Local-Dev"
exec dotnet run \
    --project "${repo_root}/btcpayserver/BTCPayServer/BTCPayServer.csproj" \
    --launch-profile Bitcoin-Mainnet-Local-Dev