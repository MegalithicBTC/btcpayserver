using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using BTCPayServer.Lightning;
using BTCPayServer.Services;
using BTCPayServer.Services.Stores;
using BTCPayServer.Data;
using BTCPayServer.Payments;
using BTCPayServer.Payments.Lightning;
using BTCPayServer.Configuration;
using BTCPayServer.Services.Invoices; // This is the missing using directive
using Microsoft.Extensions.Options;
using NBitcoin;

namespace BTCPayServer.Components.LSPS1
{
    public class LSPS1ViewComponent : ViewComponent
    {
        private readonly ILogger<LSPS1ViewComponent> _logger;
        private readonly StoreRepository _storeRepository;
        private readonly LightningClientFactoryService _lightningClientFactory;
        private readonly BTCPayNetworkProvider _networkProvider;
        private readonly PaymentMethodHandlerDictionary _handlers;
        private readonly IOptions<LightningNetworkOptions> _lightningNetworkOptions;

        public LSPS1ViewComponent(
            ILogger<LSPS1ViewComponent> logger,
            StoreRepository storeRepository,
            LightningClientFactoryService lightningClientFactory,
            BTCPayNetworkProvider networkProvider,
            PaymentMethodHandlerDictionary handlers,
            IOptions<LightningNetworkOptions> lightningNetworkOptions)
        {
            _logger = logger;
            _storeRepository = storeRepository;
            _lightningClientFactory = lightningClientFactory;
            _networkProvider = networkProvider;
            _handlers = handlers;
            _lightningNetworkOptions = lightningNetworkOptions;
        }

        public async Task<IViewComponentResult> InvokeAsync(string storeId)
        {
            _logger.LogInformation("LSPS1 component loaded!");
            
            var viewModel = new LSPS1ViewModel
            {
                HasLiquidityReport = false
            };

            if (string.IsNullOrEmpty(storeId))
            {
                return View(viewModel);
            }

            try
            {
                var store = await _storeRepository.FindStore(storeId);
                if (store == null)
                {
                    return View(viewModel);
                }

                // Get the Lightning client using the same implementation as your working service
                var client = GetLightningClient(store);
                if (client == null)
                {
                    viewModel.Message = "Could not connect to Lightning node";
                    return View(viewModel);
                }

                // Use the Liquidity.CheckAsync method from the library to check liquidity
                var liquidityReport = await Liquidity.CheckAsync(client, _logger);
                
                if (liquidityReport != null)
                {
                    viewModel.HasLiquidityReport = true;
                    viewModel.LiquidityReport = liquidityReport;
                    viewModel.Message = "Liquidity information is available for your CLightning node";
                }
                else
                {
                    viewModel.Message = "Liquidity information is only available for CLightning nodes";
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting liquidity information");
                viewModel.Message = "Error retrieving liquidity information: " + ex.Message;
            }

            return View(viewModel);
        }

        // Get lightning client implementation - based on your LightningNodeService.GetLightningClient
        private ILightningClient GetLightningClient(StoreData store)
        {
            try
            {
                var network = _networkProvider.GetNetwork<BTCPayNetwork>("BTC");
                if (network == null)
                {
                    _logger.LogError("BTC network not found");
                    return null;
                }

                var paymentMethod = PaymentTypes.LN.GetPaymentMethodId(network.CryptoCode);
                if (_handlers.TryGet(paymentMethod) is not LightningLikePaymentHandler handler)
                {
                    _logger.LogError("Lightning payment handler not available");
                    return null;
                }

                // Get payment method configuration
                var paymentMethodDetails = store.GetPaymentMethodConfig<LightningPaymentMethodConfig>(paymentMethod, _handlers);
                if (paymentMethodDetails == null)
                {
                    _logger.LogError("No Lightning payment method configured for this store");
                    return null;
                }

                try
                {
                    // First, check if we can get node info to verify connection works
                    var nodeInfo = handler.GetNodeInfo(paymentMethodDetails, null, throws: true).GetAwaiter().GetResult();
                    if (nodeInfo == null || !nodeInfo.Any())
                    {
                        _logger.LogError("Could not get node info from handler");
                        return null;
                    }
                    
                    // If connection string is empty, this might be an internal node
                    if (string.IsNullOrEmpty(paymentMethodDetails.ConnectionString))
                    {
                        _logger.LogInformation("Using internal Lightning node (empty connection string is expected)");
                        
                        // Get internal lightning client directly if available
                        if (_lightningNetworkOptions.Value.InternalLightningByCryptoCode.TryGetValue(network.CryptoCode, out var internalClient))
                        {
                            _logger.LogInformation("Using internal lightning node client");
                            return internalClient;
                        }
                        
                        _logger.LogError("No internal lightning node found for {CryptoCode}", network.CryptoCode);
                        return null;
                    }
                    
                    // Create client with connection string
                    _logger.LogInformation("Creating Lightning client with connection string");
                    return _lightningClientFactory.Create(paymentMethodDetails.ConnectionString, network);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error creating Lightning client");
                    return null;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting Lightning client");
                return null;
            }
        }
    }
}