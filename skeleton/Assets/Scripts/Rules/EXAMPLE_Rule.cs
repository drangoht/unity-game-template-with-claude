namespace __NAMESPACE__.Rules
{
    /// <summary>
    /// TEMPLATE -- copy it, then delete this file.
    ///
    /// <para>Every numeric rule of the game (curve, threshold, table, formula) lives in this
    /// folder, in a <b>static class, with no <c>using UnityEngine</c> at all</b>. That is what
    /// makes it testable in a few milliseconds by <c>dotnet test</c>, with no engine and no build:
    /// the <c>MonoBehaviour</c>s delegate here and stick to the engine work.</para>
    ///
    /// <para>A class in <c>Rules/</c> that would need the engine signals a bad split: it is up to
    /// the caller to do the engine part.</para>
    /// </summary>
    public static class ExampleRule
    {
        /// <summary>Points needed to reach the given level (level 1 = 0 points).</summary>
        /// <remarks>
        /// Gentle quadratic curve: the step grows without ever doubling from one level to the next,
        /// which avoids the progression wall in the middle of the game.
        /// </remarks>
        public static int LevelThreshold(int level)
        {
            if (level <= 1) return 0;
            int n = level - 1;
            return 5 * n * n + 10 * n;
        }
    }
}
