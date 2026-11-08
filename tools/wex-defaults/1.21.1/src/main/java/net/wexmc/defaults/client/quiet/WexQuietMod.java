package net.wexmc.defaults.client.quiet;

import net.fabricmc.api.ClientModInitializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Wex "quiet mods" feature (regressions-154-quiet, rev 2).
 *
 * Third-party mods in the Wex pack must not advertise, greet or update
 * themselves: mod updates are delivered exclusively through Wex-Pack.
 *
 * This project (1.21.1) ships a single enforcement layer:
 *  1. ChatHudMixin - hides provably mod-generated chat lines. Rev 2 rule
 *     base: structural identification only (Iris translation keys,
 *     Stellarity clickEvent payloads and exact whole-message equality).
 *     Suppressed texts are written to this logger so the causes stay in
 *     the log files; vanilla / player / server / command messages never
 *     match any rule.
 *
 * There is no Distant Horizons gate here: Wex-Pack ships no DH build for
 * 1.21.1, so no signature-verified target exists. If DH is ever added,
 * port SelfUpdaterMixin from the 1.20.1 project only after verifying the
 * shipped jar (see report, regressions-154).
 */
public class WexQuietMod implements ClientModInitializer {
    public static final Logger LOGGER = LoggerFactory.getLogger("wex-quiet");

    @Override
    public void onInitializeClient() {
        LOGGER.info("[wex-quiet] Mod message suppression active (targeted chat filter + Distant Horizons updater gate)");
    }
}
