package net.wexmc.defaults;

import net.wexmc.defaults.config.WexDefaultsConfig;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.loader.api.FabricLoader;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

public class WexDefaultsMod implements ModInitializer {
    public static final String MOD_ID = "wex-defaults";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);

    @Override
    public void onInitialize() {
        WexDefaultsConfig.load();
        LOGGER.info("[wex-defaults] Initialized (keepInventoryByDefault={}, lockCheats={})",
                WexDefaultsConfig.get().keepInventoryByDefault,
                WexDefaultsConfig.get().lockCheats);

        setupEmotes();
        setupHostCommands();
    }

    private void setupHostCommands() {
        net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            net.wexmc.defaults.command.HostBanCommands.register(dispatcher);
        });

        net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents.SERVER_STARTED.register(server -> {
            try {
                server.getPlayerManager().getUserBanList().load();
                LOGGER.info("[wex-defaults] Loaded user ban list ({} entries)",
                        server.getPlayerManager().getUserBanList().values().size());
            } catch (Throwable t) {
                LOGGER.warn("[wex-defaults] Could not load ban list: {}", t.getMessage());
            }
        });
    }

    private void setupEmotes() {
        try {
            Path gameDir = FabricLoader.getInstance().getGameDir();
            Path emotesDir = gameDir.resolve("emotes");
            Path targetFile = emotesDir.resolve("salute.json");
            if (!Files.exists(targetFile)) {
                Files.createDirectories(emotesDir);
                Path configEmote = gameDir.resolve("config").resolve("emotes").resolve("salute.json");
                if (Files.exists(configEmote)) {
                    Files.copy(configEmote, targetFile, StandardCopyOption.REPLACE_EXISTING);
                } else {
                    try (InputStream is = WexDefaultsMod.class.getResourceAsStream("/salute.json")) {
                        if (is != null) {
                            Files.copy(is, targetFile, StandardCopyOption.REPLACE_EXISTING);
                        }
                    }
                }
            }
        } catch (Throwable t) {
            LOGGER.warn("[wex-defaults] Could not extract default emotes: {}", t.getMessage());
        }
    }
}
