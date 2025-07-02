using System;
using BTCPayServer.Lightning;

namespace BTCPayServer.Components.LSPS1
{
    public class LSPS1ViewModel
    {
        public bool HasLiquidityReport { get; set; }
        public object LiquidityReport { get; set; }
        public string Message { get; set; } = "Hello World from LSPS1";
    }
}