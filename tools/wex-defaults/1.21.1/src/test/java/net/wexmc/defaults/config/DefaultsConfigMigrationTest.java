package net.wexmc.defaults.config;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import java.nio.file.Files;
import java.nio.file.Path;
import static org.junit.jupiter.api.Assertions.*;

class DefaultsConfigMigrationTest {
    @TempDir Path directory;

    @Test void copiesLegacyBytesAndKeepsOriginal() throws Exception {
        byte[] saved = "{\"keepInventoryByDefault\":false,\"lockCheats\":false}".getBytes(java.nio.charset.StandardCharsets.UTF_8);
        Files.write(directory.resolve("aura-defaults.json"), saved);
        DefaultsConfigMigration.migrate(directory);
        assertArrayEquals(saved, Files.readAllBytes(directory.resolve("wex-defaults.json")));
        assertArrayEquals(saved, Files.readAllBytes(directory.resolve("aura-defaults.json")));
    }
    @Test void existingWexSettingsAlwaysWin() throws Exception {
        Files.writeString(directory.resolve("aura-defaults.json"), "legacy");
        Files.writeString(directory.resolve("wex-defaults.json"), "current");
        DefaultsConfigMigration.migrate(directory);
        assertEquals("current", Files.readString(directory.resolve("wex-defaults.json")));
    }
    @Test void repeatedMigrationNeverReplacesEditedSettings() throws Exception {
        Files.writeString(directory.resolve("aura-defaults.json"), "legacy");
        DefaultsConfigMigration.migrate(directory);
        Files.writeString(directory.resolve("wex-defaults.json"), "edited");
        DefaultsConfigMigration.migrate(directory);
        assertEquals("edited", Files.readString(directory.resolve("wex-defaults.json")));
    }
    @Test void freshInstallNeedsNoLegacyFile() throws Exception {
        DefaultsConfigMigration.migrate(directory);
        assertFalse(Files.exists(directory.resolve("wex-defaults.json")));
    }
}
