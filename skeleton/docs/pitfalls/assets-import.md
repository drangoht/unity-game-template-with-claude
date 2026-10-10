# Pitfalls -- Assets and import


**WARNING: NEVER ignore the `.meta` files in `.gitignore`.** Unity stores the **GUID** of every asset
in them. A missing `.meta` loses every reference that pointed at the asset: scripts detached from
their GameObjects, emptied sprites. The project's `.gitignore` contains no `*.meta` rule, and that is
deliberate.

**WARNING: `Art/` and `Resources/` are not equivalent -- and getting it wrong raises nothing.**
[inherited] `Resources/` is loaded **by path** (`Resources.Load<Sprite>("Ui/button")`) and embedded
**in full** in the binary, including what is never used. `Art/` is consumed **by GUID reference**.
Writing an asset into the wrong one of the two: the generator announces "written", and the game shows
the old image. Keep a destination table (`tools/unity_paths.py`) and refer to it.

**WARNING: a file written into `Assets/` does not exist until Unity has reimported it.** A batchmode
build takes care of it, but an open editor may serve the old version from its asset database. On a
**new** file that is ignored by git, `AssetDatabase.ImportAsset` alone is not enough: an
`AssetDatabase.Refresh()` is needed first for the database to discover it.
