DOTNET_WATCH_BUILD_ALL_PROJECTS=true \
dotnet watch -p btcpayserver.sln run \
  --project BTCPayServer/BTCPayServer.csproj \
  --launch-profile Bitcoin \
  -- --bind 0.0.0.0