using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace __NAMESPACE__.EditorTools
{
    /// <summary>
    /// Checks, before every build, that DiscordRPC.dll is excluded from the web target.
    /// </summary>
    /// <remarks>
    /// <para><b>Unity's default is "everywhere".</b> A DLL dropped into <c>Plugins/</c> with a minimal
    /// <c>.meta</c> -- or whose <c>.meta</c> was lost and regenerated -- is imported for every target,
    /// the web included, where it cannot work. The module ships a correct <c>.meta</c>; this check is
    /// what keeps it true.</para>
    ///
    /// <para>Hooked on the build itself (<see cref="IPreprocessBuildWithReport"/>) rather than called
    /// from BuildTools: the module is optional, and BuildTools must not know whether it is there.</para>
    ///
    /// <para>WARNING: when the setting was wrong, it is fixed and the build is FAILED, not continued:
    /// the player scripts may already have been compiled with the old plugin list. Run the build
    /// again.</para>
    /// </remarks>
    public sealed class PluginPlatforms : IPreprocessBuildWithReport
    {
        const string DiscordDll = "Assets/Plugins/DiscordRPC.dll";

        public int callbackOrder => 0;

        public void OnPreprocessBuild(BuildReport report)
        {
            if (Apply()) throw new BuildFailedException(
                $"{DiscordDll} was not excluded from WebGL: fixed, run the build again.");
        }

        /// <summary>Applies the exclusion. Returns true if something had to change.</summary>
        [MenuItem("Tools/Fix plugin platforms")]
        public static bool Apply()
        {
            var importer = AssetImporter.GetAtPath(DiscordDll) as PluginImporter;
            if (importer == null)
            {
                Debug.LogWarning($"[PLUGINS] {DiscordDll} not found -- nothing to exclude.");
                return false;
            }

            bool changed = false;

            // "Compatible with any" then an explicit exclusion of the web: the only combination that
            // keeps the library on future targets without having to list them.
            if (!importer.GetCompatibleWithAnyPlatform())
            {
                importer.SetCompatibleWithAnyPlatform(true);
                changed = true;
            }
            if (!importer.GetExcludeFromAnyPlatform(BuildTarget.WebGL))
            {
                importer.SetExcludeFromAnyPlatform(BuildTarget.WebGL, true);
                changed = true;
            }

            if (changed) importer.SaveAndReimport();
            return changed;
        }
    }
}
