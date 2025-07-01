using System;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using BTCPayServer.Lightning;

namespace BTCPayServer.Components.LSPS1
{
    public class LSPS1ViewComponent : ViewComponent
    {
        private readonly ILogger<LSPS1ViewComponent> _logger;

        public LSPS1ViewComponent(ILogger<LSPS1ViewComponent> logger)
        {
            _logger = logger;
        }

        public IViewComponentResult Invoke()
        {
            // Print to CLI console
            Console.WriteLine("====================================");
            Console.WriteLine("HELLO WORLD FROM LSPS1 COMPONENT");
            Console.WriteLine("====================================");
            
            // Use the new Liquidity class
            string message = BTCPayServer.Lightning.Liquidity.HelloWorld();
            Console.WriteLine("Message from Liquidity class: " + message);
            
            // Also log via the logger
            _logger.LogInformation("LSPS1 component loaded via logger!");
            _logger.LogInformation(message);
            
            return View(new LSPS1ViewModel());
        }
    }
}