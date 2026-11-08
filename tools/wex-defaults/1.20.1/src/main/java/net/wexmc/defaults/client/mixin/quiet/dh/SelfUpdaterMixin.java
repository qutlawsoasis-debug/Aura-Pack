package net.wexmc.defaults.client.mixin.quiet.dh;

import net.wexmc.defaults.client.quiet.WexQuietMod;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Pseudo;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/**
 * Keeps the Distant Horizons built-in auto-updater off (rev 2 scope note).
 *
 * Wex delivers mod updates exclusively through Wex-Pack, so neither the
 * update popup (UpdateModScreen: "New update available! ... Update /
 * Always silent update / ...") nor the silent auto-update may run.
 *
 * Preferred mechanism (supported setting, belongs to Wex-Pack, NOT applied
 * by this mod - listed for the releaser):
 *   config/DistantHorizons.toml -> [client.advanced.autoUpdater]
 *   enableAutoUpdater = false   (kills the launch-time check, popup and
 *                                silent updates for every DH version)
 *   enableSilentUpdates = false (defensive, so the updater never runs
 *                                silently even if re-enabled by hand)
 *
 * Coverage of THIS mixin (honest scope): verified against the only DH build
 * actually shipped in Wex-Pack, DistantHorizons-2.2.1-a-1.20.1.jar.disabled
 * (javap: public static boolean onStart()). The pack currently ships that
 * jar DISABLED, so the mixin is dormant until DH is re-enabled. It does NOT
 * cover other DH versions (e.g. a user's older 2.1.3) - for those only the
 * Wex-Pack config above is the guaranteed path. require = 0 is crash-safety
 * against signature drift, not a coverage claim.
 *
 * DH's own gate (fabric MixinMinecraft.onOpenScreen) calls
 * SelfUpdater.onStart() on every screen open while enableAutoUpdater is
 * true; onStart() is the single entry point of the network check and drives
 * both the popup and silent downloads, so returning false here disables
 * all of it at once. @Pseudo keeps the mixin dormant when DH is absent.
 */
@Pseudo
@Mixin(targets = "com.seibel.distanthorizons.core.jar.updater.SelfUpdater", remap = false)
public abstract class SelfUpdaterMixin {
    private static boolean wexQuiet$logged = false;

    @Inject(method = "onStart()Z", at = @At("HEAD"), cancellable = true, remap = false, require = 0)
    private static void wexQuiet$disableBuiltInUpdater(CallbackInfoReturnable<Boolean> cir) {
        cir.setReturnValue(false);
        if (!wexQuiet$logged) {
            wexQuiet$logged = true;
            WexQuietMod.LOGGER.info("[wex-quiet] Distant Horizons built-in updater blocked; mod updates are delivered by Wex-Pack");
        }
    }
}
