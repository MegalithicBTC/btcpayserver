#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 0.  Kill anything still bound to :14142  (dev hot-reload safety net)
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
# 2.  Export NBXplorer cookie path  (bind-mount → ./data/nbxplorer_datadir/Main/.cookie)
###############################################################################
cookie_path="${repo_root}/btcpayserver-docker/data/nbxplorer_datadir/Main/.cookie"

# Wait (max 10 s) until NBXplorer has written the cookie file on first start-up
for i in {1..10}; do
  if [ -f "$cookie_path" ]; then break; fi
  echo "⏳  waiting for NBXplorer cookie …"
  sleep 1
done

# Ensure our local user can read the file (NBX writes it 600 root:root)
# if [ -f "$cookie_path" ]; then
#   sudo chmod a+r "$cookie_path"
# else
#   echo "❌  NBXplorer cookie not found at $cookie_path"
#   exit 1
# fi

export BTCPAY_BTCEXPLORERCOOKIEFILE="$cookie_path"
echo "📄  Using NBX cookie: $BTCPAY_BTCEXPLORERCOOKIEFILE"

###############################################################################
# 3.  Launch BTCPayServer with Ubuntu-Dev profile
###############################################################################
echo "🚀  Starting BTCPay with profile: Bitcoin-Mainnet-Ubuntu-Dev"
exec dotnet run \
     --project "${repo_root}/btcpayserver/BTCPayServer/BTCPayServer.csproj" \
     --launch-profile Bitcoin-Mainnet-Ubuntu-Dev