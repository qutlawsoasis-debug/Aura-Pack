package net.wexmc.defaults.mixin;

import net.wexmc.defaults.config.WexDefaultsConfig;
import net.minecraft.server.integrated.IntegratedServer;
import net.minecraft.world.GameMode;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.ModifyVariable;

@Mixin(IntegratedServer.class)
public abstract class IntegratedServerMixin {
    @ModifyVariable(method = "openToLan", at = @At("HEAD"), argsOnly = true, ordinal = 0)
    private boolean wex_forceLanCheatsFalse(boolean cheatsAllowed) {
        if (WexDefaultsConfig.get().lockCheats) {
            return false;
        }
        return cheatsAllowed;
    }
}
