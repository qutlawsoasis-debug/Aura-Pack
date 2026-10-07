# 🤝 Contributing to Aura Modpack

Thank you for contributing to the **Aura Modpack**! We are committed to maintaining a high-performance, immersive, and stable gaming experience for our community.

---

## 💡 Guidelines for Mod Submissions

Before suggesting or adding a new mod, ensure it meets the following criteria:

1. **Target Version**: Must be compatible with **Minecraft 1.20.1** and **Fabric Loader 0.19.5+**.
2. **Performance Impact**: Mods must not cause severe tick lag (TPS drops), memory leaks, or conflict with Sodium/Lithium.
3. **No Duplicate Features**: Avoid redundant mods that duplicate existing mechanics.
4. **Licensing**: Must be freely distributable or open-source.

---

## 🛠️ Modpack Workflow for Contributors

If you are proposing changes to mods or configs:

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/<your-username>/Aura-Pack.git
   cd Aura-Pack
   ```
2. Make your mod or configuration adjustments in `mods/` and `config/`.
3. Test in-game to verify that the client boots cleanly and joins multiplayer worlds without crashes.
4. Regenerate the cryptographic manifest using PowerShell:
   ```powershell
   .\tools\make-manifest.ps1
   ```
5. Ensure `manifest.json` is updated and matches the file tree.
6. Commit changes with a descriptive message:
   ```bash
   git commit -m "feat(mods): add Sound Physics Remastered update"
   ```
7. Open a Pull Request on GitHub.

Thank you for helping keep Aura Modpack top-tier!
