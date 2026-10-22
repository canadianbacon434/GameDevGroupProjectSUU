using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

// Entry points for building from the command line, e.g.:
//   Unity -batchmode -quit -projectPath <path> -executeMethod CommandLineBuild.Build -buildTarget mac -buildPath Builds/Mac
public static class CommandLineBuild
{
    public static void Build()
    {
        string target = GetArg("-buildTarget") ?? "mac";
        string outputDir = GetArg("-buildPath") ?? Path.Combine("Builds", target);
        bool development = Environment.GetCommandLineArgs().Contains("-development");

        BuildTarget buildTarget;
        string fileName;
        switch (target.ToLowerInvariant())
        {
            case "mac":
            case "osx":
                buildTarget = BuildTarget.StandaloneOSX;
                fileName = PlayerSettings.productName + ".app";
                break;
            case "win":
            case "windows":
                buildTarget = BuildTarget.StandaloneWindows64;
                fileName = PlayerSettings.productName + ".exe";
                break;
            case "linux":
                buildTarget = BuildTarget.StandaloneLinux64;
                fileName = PlayerSettings.productName;
                break;
            case "webgl":
                buildTarget = BuildTarget.WebGL;
                fileName = "";
                break;
            default:
                Fail($"Unknown build target '{target}'. Use mac, windows, linux or webgl.");
                return;
        }

        string[] scenes = GetScenes();
        if (scenes.Length == 0)
        {
            Fail("No scenes found to build.");
            return;
        }

        var options = new BuildPlayerOptions
        {
            scenes = scenes,
            target = buildTarget,
            locationPathName = Path.Combine(outputDir, fileName),
            options = development ? BuildOptions.Development : BuildOptions.None,
        };

        Debug.Log($"Building {buildTarget} to {options.locationPathName} with scenes: {string.Join(", ", scenes)}");
        BuildReport report = BuildPipeline.BuildPlayer(options);

        if (report.summary.result != BuildResult.Succeeded)
        {
            Fail($"Build {report.summary.result} with {report.summary.totalErrors} error(s).");
            return;
        }

        Debug.Log($"Build succeeded: {report.summary.outputPath} ({report.summary.totalSize / (1024 * 1024)} MB)");
        EditorApplication.Exit(0);
    }

    // Uses the scenes enabled in Build Settings; if none are set, builds every scene under Assets.
    static string[] GetScenes()
    {
        string[] enabled = EditorBuildSettings.scenes.Where(s => s.enabled).Select(s => s.path).ToArray();
        if (enabled.Length > 0)
            return enabled;

        return AssetDatabase.FindAssets("t:Scene", new[] { "Assets" })
            .Select(AssetDatabase.GUIDToAssetPath)
            .OrderBy(p => p)
            .ToArray();
    }

    static string GetArg(string name)
    {
        string[] args = Environment.GetCommandLineArgs();
        int i = Array.IndexOf(args, name);
        return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
    }

    static void Fail(string message)
    {
        Debug.LogError(message);
        EditorApplication.Exit(1);
    }
}
