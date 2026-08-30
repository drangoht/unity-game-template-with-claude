# Pitfalls -- Rendering (URP 2D)


**WARNING: Unity stores the active pipeline in `QualitySettings`, LEVEL BY LEVEL.** [inherited]
Filling in only `GraphicsSettings.defaultRenderPipeline` leaves the other levels on Built-in: the
game changes pipeline as soon as the player changes quality. `RenderPipelineSetup.Apply()` loops over
every level -- that is why.

**WARNING: under the 2D Renderer, a sprite with no global `Light2D` is rendered BLACK.** [inherited]
Sprites take `Sprite-Lit-Default`: without a global light in the scene, the whole set is black,
without the slightest error in the console. `SceneBuilder.BuildGlobalLight()` places one.
