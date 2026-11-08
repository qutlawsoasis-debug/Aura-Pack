package net.wexmc.defaults.client.mixin.quiet;

import net.wexmc.defaults.client.quiet.WexQuietMod;
import net.wexmc.defaults.client.quiet.QuietChatRules;
import net.minecraft.client.gui.hud.ChatHud;
import net.minecraft.client.gui.hud.MessageIndicator;
import net.minecraft.network.message.MessageSignatureData;
import net.minecraft.text.Text;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * Hides provably mod-generated chat lines (see QuietChatRules, rev 2) at the
 * single choke point every displayed chat message passes through. All display
 * paths (network game messages, tellraw, mods calling ChatHud directly) funnel
 * into these two public overloads, so no Fabric message events are needed.
 *
 * Rev 2 rule base (after Codex review): structural identification only -
 * translation keys (Iris) and clickEvent payloads / exact whole-message
 * equality (Stellarity). No prefixes, keywords or substring heuristics;
 * user / server / command / vanilla chat is never matched.
 *
 * Suppressed texts are logged by wex-quiet, so diagnostic causes (e.g. the
 * Iris shader error) remain available in the log files. Everything that does
 * not match a rule is displayed unchanged.
 *
 * Signatures verified against yarn 1.20.1+build.10 / 1.21.1+build.3:
 *   void addMessage(Text)                                        (method_1812)
 *   void addMessage(Text, MessageSignatureData, MessageIndicator) (method_44811)
 */
@Mixin(ChatHud.class)
public abstract class ChatHudMixin {

    @Inject(method = "addMessage(Lnet/minecraft/text/Text;)V", at = @At("HEAD"), cancellable = true)
    private void wexQuiet$suppressSimple(Text message, CallbackInfo ci) {
        if (QuietChatRules.shouldSuppress(message)) {
            WexQuietMod.LOGGER.info("[wex-quiet] Suppressed mod chat message: {}", QuietChatRules.describe(message));
            ci.cancel();
        }
    }

    @Inject(method = "addMessage(Lnet/minecraft/text/Text;Lnet/minecraft/network/message/MessageSignatureData;Lnet/minecraft/client/gui/hud/MessageIndicator;)V", at = @At("HEAD"), cancellable = true)
    private void wexQuiet$suppressFull(Text message, MessageSignatureData signature, MessageIndicator indicator, CallbackInfo ci) {
        if (QuietChatRules.shouldSuppress(message)) {
            WexQuietMod.LOGGER.info("[wex-quiet] Suppressed mod chat message: {}", QuietChatRules.describe(message));
            ci.cancel();
        }
    }
}
