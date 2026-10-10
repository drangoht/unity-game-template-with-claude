using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using UnityEngine.InputSystem.UI;

namespace __NAMESPACE__.EditorTools
{
    /// <summary>
    /// Builds the game scene <b>entirely in code</b>, then writes it to disk.
    ///
    /// <para>This is the structuring choice of the template: the scene is an <b>artefact</b>,
    /// regenerated at every build, and not a file edited with the mouse. In exchange, the whole
    /// game can be driven without ever opening the editor -- an agent can change a position, run
    /// the build again in batchmode and look at the result, which a hand-edited <c>.unity</c> file
    /// makes impossible.</para>
    /// </summary>
    /// <remarks>
    /// WARNING: consequence to know about -- <c>Assets/Scenes/Game.unity</c> comes out <b>modified
    /// after every build</b>, because the regeneration renumbers every <c>fileID</c> -- thousands
    /// of diff lines for an identical scene. Discard it (<c>git checkout --</c>) unless
    /// <c>SceneBuilder.cs</c> has changed, in which case the regeneration carries a real
    /// difference. <c>BuildTools.HasLocalChanges</c> already excludes it from the tree cleanliness
    /// check.
    ///
    /// WARNING: do not add anything here that depends on a missing asset: a batchmode build fails
    /// on a null reference without any way to see it in the editor.
    /// </remarks>
    public static class SceneBuilder
    {
        public const string ScenePath = "Assets/Scenes/Game.unity";

        [MenuItem("__GAME_NAME__/Regenerate the scene")]
        public static void Build()
        {
            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            BuildCamera();
            BuildGlobalLight();
            BuildEventSystem();
            BuildStampCanvas();

            // ---- The game starts here ------------------------------------------------------
            // Add your own building methods (ground, player, HUD, menus, ...). Keep them short and
            // named after what they place: this list is what gets re-read to know what the scene is
            // made of.
            // ---------------------------------------------------------------------------------

            Directory.CreateDirectory(Path.GetDirectoryName(ScenePath));
            EditorSceneManager.SaveScene(scene, ScenePath);
            AssetDatabase.SaveAssets();

            Debug.Log($"Scene regenerated: {ScenePath}");
        }

        static void BuildCamera()
        {
            var go = new GameObject("Main Camera");
            var camera = go.AddComponent<Camera>();
            camera.orthographic = true;
            camera.orthographicSize = 5f;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.10f, 0.10f, 0.18f);
            camera.transform.position = new Vector3(0f, 0f, -10f);
            go.tag = "MainCamera";

            // The camera's URP data is a separate component: without it, the camera falls back on
            // default values and ignores the 2D renderer.
            go.AddComponent<UniversalAdditionalCameraData>();
        }

        /// <summary>
        /// WARNING: the global light is not decorative -- under the 2D Renderer, a sprite in
        /// <c>Sprite-Lit-Default</c> with no <c>Light2D</c> at all is rendered <b>black</b>. The
        /// game then displays entirely dark, without the slightest error in the console.
        /// </summary>
        static void BuildGlobalLight()
        {
            var go = new GameObject("Global Light 2D");
            var light = go.AddComponent<Light2D>();
            light.lightType = Light2D.LightType.Global;
            light.intensity = 1f;
            light.color = Color.white;
        }

        /// <summary>
        /// WARNING: <c>InputSystemUIInputModule</c> and not <c>StandaloneInputModule</c> -- with
        /// the Input System package active, the old module receives nothing and the UI simply stops
        /// responding.
        /// </summary>
        static void BuildEventSystem()
        {
            var go = new GameObject("EventSystem");
            go.AddComponent<UnityEngine.EventSystems.EventSystem>();
            go.AddComponent<InputSystemUIInputModule>();
        }

        /// <summary>
        /// The build stamp lives on its <b>own</b> canvas rather than in the HUD: the HUD goes
        /// dark as soon as a menu opens, and menus are exactly where most screenshots are taken.
        /// </summary>
        static void BuildStampCanvas()
        {
            var canvasGo = new GameObject("Build Stamp Canvas");
            var canvas = canvasGo.AddComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 1000;
            var scaler = canvasGo.AddComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1280f, 720f);
            canvasGo.AddComponent<GraphicRaycaster>();

            var labelGo = new GameObject("Stamp");
            labelGo.transform.SetParent(canvasGo.transform, false);

            var text = labelGo.AddComponent<Text>();
            text.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            text.fontSize = 14;
            text.alignment = TextAnchor.LowerRight;
            text.color = new Color(1f, 1f, 1f, 0.45f);
            text.raycastTarget = false;

            var rect = labelGo.GetComponent<RectTransform>();
            rect.anchorMin = new Vector2(1f, 0f);
            rect.anchorMax = new Vector2(1f, 0f);
            rect.pivot = new Vector2(1f, 0f);
            rect.anchoredPosition = new Vector2(-12f, 8f);
            rect.sizeDelta = new Vector2(300f, 20f);

            labelGo.AddComponent<BuildStampLabel>();
        }
    }
}
