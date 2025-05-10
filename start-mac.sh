cd ../btcpayserver-plugin-template/BTCPayServer.Plugins.LSPS1
dotnet build 
cd ../..
cd btcpayserver 
dotnet run  \
  --project BTCPayServer/BTCPayServer.csproj \
  --launch-profile Bitcoin 