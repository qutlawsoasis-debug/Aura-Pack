package net.wexmc.defaults.config;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

/** Copies legacy settings once without deleting or overwriting player files. */
public final class DefaultsConfigMigration {
    private DefaultsConfigMigration() { }

    public static void migrate(Path configDirectory) throws IOException {
        Path legacy = configDirectory.resolve("aura-defaults.json");
        Path current = configDirectory.resolve("wex-defaults.json");
        if (!Files.exists(current) && Files.isRegularFile(legacy)) {
            Files.copy(legacy, current);
        }
    }
}
