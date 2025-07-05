#nullable enable
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using BTCPayServer.Lightning;
using BTCPayServer.Lightning.CLightning;
using BTCPayServer.Lightning.JsonConverters;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

namespace BTCPayServer.Components.LSPS1
{
    /// <summary>
    /// Overall inbound-liquidity health.
    /// </summary>
    public enum LiquidityStatus
    {
        Good,
        Pending,
        Bad
    }

    /// <summary>
    /// DTO returned when liquidity could be analysed.
    /// </summary>
    public class LiquidityReport
    {
        public LiquidityStatus LiquidityStatus { get; set; }

        [JsonConverter(typeof(LightMoneyJsonConverter))]
        public LightMoney ActiveInboundSatoshis { get; set; } = LightMoney.Zero;

        [JsonConverter(typeof(LightMoneyJsonConverter))]
        public LightMoney PendingInboundSatoshis { get; set; } = LightMoney.Zero;
    }

    /// <summary>
    /// Helper for checking Core-Lightning inbound liquidity.
    /// </summary>
    public static class Liquidity
    {
        private static readonly LightMoney DefaultThreshold = LightMoney.Satoshis(250_000);

        /// <summary>
        /// Returns <c>null</c> when the supplied node is not Core-Lightning or
        /// if an error occurs; otherwise returns a populated <see cref="LiquidityReport"/>.
        /// </summary>
        public static async Task<LiquidityReport?> CheckAsync(
            ILightningClient client,
            ILogger? logger = null,
            LightMoney? threshold = null,
            CancellationToken token = default)
        {
            // This check is specific to CLN because it's the only implementation
            // where ListChannels returns pending channels.
            if (client is not CLightningClient)
            {
                logger?.LogInformation("[Liquidity] Liquidity check is only supported for CLN. Aborting check.");
                return null;
            }

            var min = threshold ?? DefaultThreshold;
            logger?.LogInformation("[Liquidity] Using inbound liquidity threshold of {Threshold} sats", min.ToUnit(LightMoneyUnit.Satoshi));

            try
            {
                logger?.LogInformation("[Liquidity] Attempting to list channels...");
                var channels = await client.ListChannels(token);

                if (channels is null)
                {
                    logger?.LogWarning("[Liquidity] ListChannels returned null. This can happen if a channel is opening. Aborting check.");
                    return null;
                }

                logger?.LogInformation("[Liquidity] Found {ChannelCount} channels.", channels.Length);

                // inbound capacity = total – local
                LightMoney activeInbound = channels.Where(c => c.IsActive)
                                                    .Aggregate(LightMoney.Zero,
                                                               (s, ch) => s + (ch.Capacity - ch.LocalBalance));

                LightMoney pendingInbound = channels.Where(c => !c.IsActive)
                                                     .Aggregate(LightMoney.Zero,
                                                                (s, ch) => s + (ch.Capacity - ch.LocalBalance));

                logger?.LogInformation("[Liquidity] Calculated Active Inbound: {ActiveInbound} sats", activeInbound.ToUnit(LightMoneyUnit.Satoshi));
                logger?.LogInformation("[Liquidity] Calculated Pending Inbound: {PendingInbound} sats", pendingInbound.ToUnit(LightMoneyUnit.Satoshi));

                var status = LiquidityStatus.Bad;
                if (activeInbound >= min)
                    status = LiquidityStatus.Good;
                else if (pendingInbound >= min)
                    status = LiquidityStatus.Pending;

                logger?.LogInformation("[Liquidity] Determined liquidity status: {Status}", status);

                var report = new LiquidityReport
                {
                    LiquidityStatus = status,
                    ActiveInboundSatoshis = activeInbound,
                    PendingInboundSatoshis = pendingInbound
                };
                logger?.LogInformation("[Liquidity] CheckAsync finished successfully. Returning report.");
                return report;
            }
            catch (Exception ex)
            {
                logger?.LogError(ex, "[Liquidity] CheckAsync failed with an exception.");
                // Return null instead of re-throwing to allow the UI to handle it gracefully.
                return null;
            }
        }
    }
}