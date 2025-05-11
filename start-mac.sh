#!/usr/bin/env bash
set -euo pipefail            # fail hard on any error

# ----------------------------------------------------------------------
# 1. If something is already listening on 14142, kill it cleanly
# ----------------------------------------------------------------------
if lsof -i :14142 -sTCP:LISTEN -t >/dev/null; then
  echo "BTCPay is already running on port 14142 – stopping it …"

  # try a graceful shutdown first (SIGTERM)
  pkill -f 'dotnet.*BTCPayServer' || true

  # give it a moment, then force-kill anything still on the port
  sleep 2
  lsof -ti :14142 -sTCP:LISTEN | xargs -r kill -9
fi

# ----------------------------------------------------------------------
# 2. Rebuild the LSPS1 plugin
# ----------------------------------------------------------------------
cd ../btcpayserver-plugin-template/BTCPayServer.Plugins.LSPS1
dotnet build -c Debug

# ----------------------------------------------------------------------
# 3. Run BTCPay Server (Bitcoin launch profile)
# ----------------------------------------------------------------------
cd ../../btcpayserver
# dotnet run \
#   --project BTCPayServer/BTCPayServer.csproj \
#   --launch-profile Bitcoin
dotnet run --project BTCPayServer/BTCPayServer.csproj --launch-profile Bitcoin-Mainnet-Local-Dev