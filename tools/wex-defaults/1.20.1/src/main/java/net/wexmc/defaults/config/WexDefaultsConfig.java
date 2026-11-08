package net.wexmc.defaults.config;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;

import java.io.Reader;
import java.io.Writer;
import java.nio.file.Files;
import java.nio.file.Path;

public class WexDefaultsConfig {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    private static final Path CONFIG_PATH = FabricLoader.getInstance().getConfigDir().resolve("wex-defaults.json");
    private static WexDefaultsConfig instance = new WexDefaultsConfig();

    public boolean keepInventoryByDefault = true;
    public boolean lockCheats = true;

    public static WexDefaultsConfig get() {
        if (instance == null) {
            load();
        }
        return instance;
    }

    public static void load() {
        try {
            DefaultsConfigMigration.migrate(CONFIG_PATH.getParent());
        } catch (java.io.IOException e) {
            throw new IllegalStateException("Cannot preserve legacy defaults settings", e);
        }
        if (Files.exists(CONFIG_PATH)) {
            try (Reader reader = Files.newBufferedReader(CONFIG_PATH)) {
                WexDefaultsConfig loaded = GSON.fromJson(reader, WexDefaultsConfig.class);
                if (loaded != null) {
                    instance = loaded;
                    return;
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }

        instance = new WexDefaultsConfig();
        save();
    }

    public static void save() {
        try {
            if (!Files.exists(CONFIG_PATH.getParent())) {
                Files.createDirectories(CONFIG_PATH.getParent());
            }
            try (Writer writer = Files.newBufferedWriter(CONFIG_PATH)) {
                GSON.toJson(instance, writer);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
