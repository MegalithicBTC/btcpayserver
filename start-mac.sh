#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 0.  Kill anything still bound to :14142 (gracefully, then force if needed)
###############################################################################
if lsof -i :14142 -sTCP:LISTEN -t >/dev/null; then
  echo "🔄  BTCPay already running on :14142 – stopping it …"
  pkill -f 'dotnet.*BTCPayServer' || true
  sleep 2
  lsof -ti :14142 -sTCP:LISTEN | xargs -r kill -9
fi

###############################################################################
# 1.  Rebuild the LSPS1 plugin (Debug)
###############################################################################
echo "🔨  Building LSPS1 plugin …"
cd ../btcpayserver-plugin-template/BTCPayServer.Plugins.LSPS1
dotnet build -c Debug

###############################################################################
# 2.  Compute & export the NBX cookie path
###############################################################################
cd ../../btcpayserver   # back to BTCPay solution root

COOKIE_PATH="$(cd ../btcpayserver-docker/data/nbxplorer/Main && pwd)/.cookie"
export BTCPAY_BTCEXPLORERCOOKIEFILE="$COOKIE_PATH"

echo "📄  Using NBX cookie: $BTCPAY_BTCEXPLORERCOOKIEFILE"

###############################################################################
# 3.  Launch BTCPay (Mainnet, local dev profile)
#     - exec replaces the shell so ^C cleanly stops BTCPay
###############################################################################
echo "🚀  Starting BTCPay with profile: Bitcoin-Mainnet-Local-Dev"
exec dotnet run \
    --project BTCPayServer/BTCPayServer.csproj \
    --launch-profile Bitcoin-Mainnet-Local-Dev