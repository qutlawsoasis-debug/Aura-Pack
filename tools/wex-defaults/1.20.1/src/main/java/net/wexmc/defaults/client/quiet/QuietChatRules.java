package net.wexmc.defaults.client.quiet;

import net.minecraft.text.ClickEvent;
import net.minecraft.text.Text;
import net.minecraft.text.TranslatableTextContent;

/**
 * Targeted suppression rules for third-party mod chat noise (rev 2, revised
 * after Codex review).
 *
 * A message is suppressed only when its ORIGIN is provable:
 *
 *  1. Iris shader-load failure: the component is a translatable text whose
 *     key starts with "iris.load.failure." (verified in Iris 1.7.6 /
 *     1.8.14: key "iris.load.failure.generic"). Matching the translation key
 *     is language-independent and structural. Iris itself logs the real
 *     shader error; hiding the chat line does not lose the cause.
 *
 *  2. Stellarity links/commands: anywhere in the component tree there is a
 *     clickEvent whose value is EXACTLY one of the source-verified
 *     Stellarity URLs (open_url) or a run_command in the "stellarity:"
 *     datapack namespace. clickEvent payloads are interaction data, not
 *     visible text - players cannot produce them by typing chat, and a
 *     forged byte-identical payload is indistinguishable from the mod by
 *     any client-side means.
 *
 *  3. Stellarity static rows without click events: EXACT whole-message
 *     equality against constants extracted mechanically from the mod jars.
 *     This is the tightest client-side identification possible for plain
 *     styled text (no prefix, no substring, no keyword heuristics).
 *
 * Removed in rev 2 per review (plain-text matching does not prove origin):
 * the "| '" MOTD prefix rule, the "|" + keyword safety net, the "| " bar
 * equality (also made unreachable by trim), the English text-prefix
 * fallback for Iris, and trim-based comparison in general.
 *
 * Visible remainders by design: "| " decoration bars, the dynamic MOTD row
 * ("| ' ... '") and empty spacer lines of the Stellarity block. The
 * preferred complete fix is source-side: datapack scoreboard
 * stellarity.config.join_message = 0 (server-side task, listed for the
 * releaser in the report; outside this mod's client-only quiet zone).
 *
 * Vanilla / player / server / command messages never match any rule.
 */
public final class QuietChatRules {
    private QuietChatRules() {
    }

    /** Iris shader-load failures: structural match by translation key. */
    private static final String IRIS_KEY_PREFIX = "iris.load.failure";

    /**
     * Stellarity link rows (v2 tellraw.mcfunction and v3 send.mcfunction).
     * Exact open_url values; no prefixes.
     */
    private static final String[] STELLARITY_CLICK_URLS = {
        // Stellarity v2 (Wex-Pack 1.20.1)
        "https://ko-fi.com/kohara",
        "https://discord.gg/J6guYAySN8",
        // Stellarity 3.x (Wex-Pack 1.21.1)
        "https://prismaticshards.wiki.gg/wiki/Stellarity",
        "http://discord.prismaticshards.xyz",
        "https://github.com/Prismatic-Shards/translations",
        "https://bisecthosting.com/kohara",
        "https://github.com/Prismatic-Shards/Stellarity",
        "https://curseforge.com/minecraft/mc-mods/stellarity",
        "https://modrinth.com/datapack/stellarity",
    };

    /**
     * Stellarity static rows without click events, extracted mechanically
     * from the jars (v2: tellraw.mcfunction; v3: send.mcfunction).
     * Compared as exact whole messages, no trimming.
     */
    private static final String[] STELLARITY_EXACT_LINES = {
        // Stellarity v2 (1.20.1)
        "Stellarity has successfully loaded!",
        "Made by kohara",
        "Originally made by Hex",
        // Stellarity 3.x (1.21.1)
        "| ⭐ Stellarity ⭐ has succesfully loaded!",
        "|      Cʀᴇᴀᴛᴇᴅ ʙʏ ᴋᴏʜᴀʀᴀ",
        "|      Mᴀɪɴᴛᴀɪɴᴇᴅ ʙʏ ᴘʀɪѕᴍᴀᴛɪᴄ ѕʜᴀʀᴅѕ",
        "| Usᴇғᴜʟ Lɪɴᴋs",
        "| Pʀᴏᴊᴇᴄᴛ Pᴀɢᴇ",
    };

    public static boolean shouldSuppress(Text message) {
        if (message == null) {
            return false;
        }

        if (message.getContent() instanceof TranslatableTextContent translatable
                && translatable.getKey().startsWith(IRIS_KEY_PREFIX)) {
            return true;
        }

        if (hasStellarityClickEvent(message)) {
            return true;
        }

        String plain = message.getString();
        if (plain == null || plain.isEmpty()) {
            return false;
        }
        for (String exact : STELLARITY_EXACT_LINES) {
            if (plain.equals(exact)) {
                return true;
            }
        }
        return false;
    }

    /** Short human-readable description used for the log line when a message is hidden. */
    public static String describe(Text message) {
        if (message != null && message.getContent() instanceof TranslatableTextContent translatable) {
            return "[key=" + translatable.getKey() + "] " + message.getString();
        }
        return message == null ? "" : message.getString();
    }

    /**
     * Structural identification: walks the component tree (root + siblings)
     * looking for Stellarity click events. ClickEvent accessors are stable
     * across yarn 1.20.1 / 1.21.1 (Style.getClickEvent, ClickEvent.getAction,
     * ClickEvent.getValue - verified against both mappings).
     */
    private static boolean hasStellarityClickEvent(Text text) {
        ClickEvent click = text.getStyle().getClickEvent();
        if (click != null && click.getValue() != null) {
            String value = click.getValue();
            if (click.getAction() == ClickEvent.Action.RUN_COMMAND
                    && value.startsWith("/function stellarity:")) {
                return true;
            }
            if (click.getAction() == ClickEvent.Action.OPEN_URL) {
                for (String url : STELLARITY_CLICK_URLS) {
                    if (value.equals(url)) {
                        return true;
                    }
                }
            }
        }
        for (Text sibling : text.getSiblings()) {
            if (hasStellarityClickEvent(sibling)) {
                return true;
            }
        }
        return false;
    }
}
