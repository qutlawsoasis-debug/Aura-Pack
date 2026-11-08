# Wex Defaults source

Source imported from the AuraDev repository, directories aura-defaults/ and aura-defaults-1.21/, last source commit 73e7824a7cfe50fb84a7de930f2385a5969bed4b. Upstream namespaces and resources were renamed to net.wexmc / wex-defaults. License: MIT, see the pack root LICENSE.

Both Minecraft profiles build together using Gradle 8.8, Java 21 and Fabric Loom. Run from this directory, keeping all generated files outside the repository:

```powershell
gradle build --no-daemon --max-workers=2 --project-cache-dir <external-cache> -PdefaultsBuildDir=<external-build>
```

The two remapped artifacts are <external-build>/1.20.1/libs/wex-defaults-1.0.1.jar and <external-build>/1.21.1/libs/wex-defaults-1.0.1.jar. Tests run with the build; verifyDefaultsJar rejects duplicate onboarding, warning/backup, Realms and integrated-loader menu mixins. Jar timestamps and ordering are reproducible.

Cheat-lock behavior, gamerules, host ban, quiet chat and update notices remain. The only client screen mixins retained implement cheat locking. Experimental world lifecycle checks and backup prompts are handled by Minecraft; Wex Defaults never calls their callbacks during screen initialization.

On first load, config/aura-defaults.json is copied to config/wex-defaults.json if the latter is absent. Legacy settings are never deleted; existing Wex settings always win. Host ban data and the launcher update-notice.json / pack-state.json contract retain their Minecraft/launcher filenames. GitHub repository Aura-Pack is intentionally unchanged.
