package net.wexmc.defaults.client.mixin;

import net.wexmc.defaults.config.WexDefaultsConfig;
import net.minecraft.client.gui.screen.world.WorldCreator;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.ModifyVariable;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(WorldCreator.class)
public abstract class WorldCreatorMixin {
    @ModifyVariable(method = "setCheatsEnabled", at = @At("HEAD"), argsOnly = true, ordinal = 0)
    private boolean wex_forceCheatsDisabled(boolean cheatsEnabled) {
        if (WexDefaultsConfig.get().lockCheats) {
            return false;
        }
        return cheatsEnabled;
    }

    @Inject(method = "areCheatsEnabled", at = @At("HEAD"), cancellable = true)
    private void wex_forceAreCheatsEnabledFalse(CallbackInfoReturnable<Boolean> cir) {
        if (WexDefaultsConfig.get().lockCheats) {
            cir.setReturnValue(false);
        }
    }
}
