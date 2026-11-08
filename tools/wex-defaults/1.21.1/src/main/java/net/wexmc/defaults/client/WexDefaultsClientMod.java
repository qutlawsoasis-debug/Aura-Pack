package net.wexmc.defaults.client;

import net.fabricmc.api.ClientModInitializer;

public final class WexDefaultsClientMod implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        WexUpdateNoticeHandler.init();
    }
}
