package net.wexmc.defaults.client.quiet;

import net.fabricmc.api.ClientModInitializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Wex "quiet mods" feature (regressions-154-quiet, rev 2).
 *
 * Third-party mods in the Wex pack must not advertise, greet or update
 * themselves: mod updates are delivered exclusively through Wex-Pack.
 * This feature has two enforcement layers, both client-side and cheap:
 *
 *  1. ChatHudMixin - hides provably mod-generated chat lines. Rev 2 rule
 *     base: structural identification only (Iris translation keys,
 *     Stellarity clickEvent payloads and exact whole-message equality).
 *     Suppressed texts are written to this logger so the causes stay in
 *     the log files; vanilla / player / server / command messages never
 *     match any rule.
 *  2. SelfUpdaterMixin - keeps the Distant Horizons built-in updater
 *     (popup and silent auto-update) disabled for the shipped DH build
 *     (2.2.1-a-1.20.1, signature-verified); the supported config path
 *     (enableAutoUpdater=false in DistantHorizons.toml) remains the
 *     preferred mechanism for every DH version and is listed for the
 *     releaser.
 */
public class WexQuietMod implements ClientModInitializer {
    public static final Logger LOGGER = LoggerFactory.getLogger("wex-quiet");

    @Override
    public void onInitializeClient() {
        LOGGER.info("[wex-quiet] Mod message suppression active (targeted chat filter + Distant Horizons updater gate)");
    }
}
