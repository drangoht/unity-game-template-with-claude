#if !UNITY_WEBGL
using DiscordRPC;
#endif
using UnityEngine;

namespace __NAMESPACE__
{
    /// <summary>
    /// Discord Rich Presence: "Playing __GAME_NAME__" on the player's Discord status, with what they
    /// are doing and the session timer. Optional module of unity-game-template (`new-game.ps1 -Discord`).
    ///
    /// <para><b>Tolerant of Discord being absent</b>, and that is not a detail: when the client is not
    /// running -- the case of most players -- the connection fails and the game goes on without a
    /// word. An optional extra must never be able to stop anyone from playing.</para>
    ///
    /// <para><b>Absent from the web build, and it cannot be otherwise.</b> The presence goes through a
    /// local named pipe to the installed client; a web page has access to neither, and the library
    /// opens threads WebGL does not provide. The DLL is excluded from the WebGL target (its
    /// <c>.meta</c>, checked by <c>PluginPlatforms</c> at every build), and the code compiles to
    /// nothing there.</para>
    ///
    /// <para>The image keys (<see cref="LargeImageKey"/>, <see cref="SmallImageKey"/>) refer to the
    /// Art Assets of the application on the Discord developer portal: they do not live in the repo.
    /// docs/pitfalls/discord.md has the set-up checklist.</para>
    /// </summary>
    public sealed class DiscordPresence : MonoBehaviour
    {
        /// <summary>
        /// Application ID from discord.com/developers. Empty = the module is installed but not
        /// configured: nothing connects, and <see cref="Available"/> hides the options switch.
        /// </summary>
        const string AppId = "__DISCORD_APP_ID__";

        const string LargeImageKey = "__GAME_SLUG__";
        const string SmallImageKey = LargeImageKey + "_small";
        const string PrefsKey = "__GAME_SLUG__.discord";

        public static DiscordPresence Instance { get; private set; }

        /// <summary>
        /// Does the presence make sense here? <b>Check it before offering the switch</b>: on the web,
        /// or without an Application ID, the answer is no and the switch must not exist -- a setting
        /// that can be flipped without effect is a defect, not a feature.
        /// </summary>
        public static bool Available
        {
            get
            {
#if UNITY_WEBGL
                return false;
#else
                // WARNING: compared to the token too. A project generated without -DiscordAppId and
                // edited by hand may keep it: it is not an ID, and connecting with it fails silently.
                return AppId.Length > 0 && !AppId.StartsWith("__");
#endif
            }
        }

        /// <summary>
        /// The player's choice, kept by this class rather than by the game's settings: the module
        /// then works the moment it is copied, and the switch cannot be orphaned (a saved setting
        /// nobody reads -- the defect Chimera Protocol shipped). Applied on the spot.
        /// </summary>
        public static bool Enabled
        {
            get => PlayerPrefs.GetInt(PrefsKey, 1) == 1;
            set
            {
                PlayerPrefs.SetInt(PrefsKey, value ? 1 : 0);
                PlayerPrefs.Save();
                if (Instance != null) Instance.Apply();
            }
        }

        /// <summary>Is the presence actually connected? Observable by tests and logs.</summary>
        public bool IsConnected
        {
            get
            {
#if UNITY_WEBGL
                return false;
#else
                return client != null;
#endif
            }
        }

        /// <summary>Updates sent since launch -- tells "connected" apart from "connected but mute".</summary>
        public int Updates { get; private set; }

        string details = "In the menus";
        string state;

#if !UNITY_WEBGL
        DiscordRpcClient client;
        Timestamps sessionStart;
#endif

        /// <summary>Installs itself at startup: nothing to place in the scene.</summary>
        /// <remarks>
        /// Never in batch mode: a headless test run has no status to publish, and would make the
        /// status of the player who launches it flicker.
        /// </remarks>
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Install()
        {
            if (!Available || Application.isBatchMode || Instance != null) return;

            var host = new GameObject("[DiscordPresence]");
            host.AddComponent<DiscordPresence>();
            DontDestroyOnLoad(host);
        }

        void Awake()
        {
            Instance = this;
            Apply();
        }

        /// <summary>
        /// What the player is doing: <paramref name="details"/> is the first line, <paramref name="state"/>
        /// the second (null = none). Callable from anywhere, at any time, even with Discord absent.
        /// </summary>
        /// <remarks>
        /// WARNING: Discord accepts one update every 15 s and silently drops the rest. Call this on
        /// CHANGES (a new phase, a milestone), never from Update(): identical statuses are filtered
        /// here, but a value that moves every frame would still flood the pipe.
        /// </remarks>
        public static void SetStatus(string details, string state = null)
        {
            if (Instance == null) return;
            if (details == Instance.details && state == Instance.state) return;

            Instance.details = details;
            Instance.state = state;
            Instance.Push();
        }

        void Apply()
        {
            if (Enabled == IsConnected) return;
            if (Enabled) Connect();
            else Shutdown();
        }

        void Connect()
        {
#if !UNITY_WEBGL
            try
            {
                client = new DiscordRpcClient(AppId);
                client.Initialize();
                sessionStart ??= Timestamps.Now;
                Push();

                // WARNING: logged on SUCCESS too. Without this line, a silent log does not tell
                // "connected" apart from "never installed".
                Debug.Log($"[DiscordPresence] connected (app {AppId}).");
            }
            catch (System.Exception e)
            {
                // Discord absent or pipe unavailable: the usual case, not a defect -- no error.
                Debug.Log($"[DiscordPresence] disabled ({e.Message})");
                client?.Dispose();
                client = null;
            }
#endif
        }

        void Push()
        {
#if !UNITY_WEBGL
            if (client == null) return;
            try
            {
                client.SetPresence(new RichPresence
                {
                    Details = details,
                    State = state,
                    Timestamps = sessionStart,
                    Assets = new Assets
                    {
                        LargeImageKey = LargeImageKey,
                        LargeImageText = "__GAME_NAME__",
                        SmallImageKey = SmallImageKey,
                    },
                });
                Updates++;
            }
            catch (System.Exception e)
            {
                Debug.Log($"[DiscordPresence] update skipped ({e.Message})");
            }
#endif
        }

        /// <summary>
        /// On OnApplicationQuit AND OnDestroy: closing the window does not go through the same callbacks
        /// as leaving Play mode, and a pipe left open freezes the player's status on "playing" until
        /// Discord restarts.
        /// </summary>
        void OnApplicationQuit() => Shutdown();

        void OnDestroy()
        {
            Shutdown();
            if (Instance == this) Instance = null;
        }

        void Shutdown()
        {
#if !UNITY_WEBGL
            if (client == null) return;
            try { client.ClearPresence(); } catch { /* the pipe may already be closed */ }
            try { client.Dispose(); } catch { /* same */ }
            client = null;
#endif
        }
    }
}
