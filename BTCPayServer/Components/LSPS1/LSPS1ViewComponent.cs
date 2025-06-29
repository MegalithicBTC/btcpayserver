using System;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

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
            Console.WriteLine("HELLO WORLD FROM LSPS1");
            Console.WriteLine("====================================");
            
            // Also log via the logger
            _logger.LogInformation("LSPS1 component loaded via logger!");
            
            return View(new LSPS1ViewModel());
        }
    }
}