package net.wexmc.defaults.client.mixin;

import net.wexmc.defaults.config.WexDefaultsConfig;
import net.minecraft.client.gui.tooltip.Tooltip;
import net.minecraft.client.gui.widget.CyclingButtonWidget;
import net.minecraft.client.gui.widget.PressableWidget;
import net.minecraft.screen.ScreenTexts;
import net.minecraft.text.Text;
import net.minecraft.text.TranslatableTextContent;
import org.spongepowered.asm.mixin.Final;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Mutable;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.Unique;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(CyclingButtonWidget.class)
public abstract class CyclingButtonWidgetMixin<T> extends PressableWidget {
    @Shadow
    @Final
    private Text optionText;

    @Shadow
    @Mutable
    private T value;

    @Shadow
    private int index;

    protected CyclingButtonWidgetMixin(int x, int y, int width, int height, Text message) {
        super(x, y, width, height, message);
    }

    @Unique
    private boolean wex_isAllowCommandsButton() {
        if (!WexDefaultsConfig.get().lockCheats || this.optionText == null) {
            return false;
        }
        if (this.optionText.getContent() instanceof TranslatableTextContent translatable) {
            return "selectWorld.allowCommands".equals(translatable.getKey());
        }
        String expected = Text.translatable("selectWorld.allowCommands").getString();
        return !expected.isEmpty() && this.optionText.getString().contains(expected);
    }

    @Unique
    @SuppressWarnings("unchecked")
    private void wex_enforceLockedOff() {
        if (!wex_isAllowCommandsButton()) {
            return;
        }
        if (this.value instanceof Boolean) {
            this.value = (T) Boolean.FALSE;
            this.index = 1;
            this.setMessage(ScreenTexts.composeGenericOptionText(this.optionText, ScreenTexts.OFF));
        }
        this.active = false;
        this.setTooltip(Tooltip.of(Text.literal("Отключено в Wex")));
    }

    @Inject(method = "<init>", at = @At("TAIL"))
    private void wex_onInit(CallbackInfo ci) {
        wex_enforceLockedOff();
    }

    @Inject(method = "setValue", at = @At("TAIL"))
    private void wex_onSetValue(T value, CallbackInfo ci) {
        wex_enforceLockedOff();
    }

    @Inject(method = "onPress", at = @At("HEAD"), cancellable = true)
    private void wex_onPress(CallbackInfo ci) {
        if (wex_isAllowCommandsButton()) {
            wex_enforceLockedOff();
            ci.cancel();
        }
    }

    @Inject(method = "mouseScrolled", at = @At("HEAD"), cancellable = true)
    private void wex_onMouseScrolled(double mouseX, double mouseY, double horizontalAmount, double verticalAmount, CallbackInfoReturnable<Boolean> cir) {
        if (wex_isAllowCommandsButton()) {
            wex_enforceLockedOff();
            cir.setReturnValue(false);
        }
    }
}
