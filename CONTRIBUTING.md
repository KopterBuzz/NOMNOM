# NOMNOM Documentation // Contribution Guide

### Example Manifest:

```json
{
    "id": "your.example.mod",
    "displayName": "Example Mod",
    "description": "This is an example manifest for a mod.",
    "isClientOrServer": "Both",
    "tags": [
        "mod",
        "example"
    ],
    "urls": [
        {
            "name": "info",
            "url": "https://github.com/yourGithub/example-mod"
        }
    ],
    "authors": [
        "yourName"
    ],
    "autoUpdateArtifacts": "True",
    "githubOwner": "yourGithub",
    "githubRepoName": "example-mod",
    "artifacts": [
        {
            "fileName": "Aryx_F22E_StrikeRaptor_1.0.4.dll",
            "version": "1.0.4",
            "category": "release",
            "type": "addon",
            "gameVersion": "0.34",
            "downloadUrl": "https://github.com/Aryx3D/Aryx_F22E_StrikeRaptor/releases/download/1.0.4/Aryx_F22E_StrikeRaptor_1.0.4.dll",
            "hash": "sha256:c57b70ca9859b7638935d30ec3a60b697d8bbdf608f00d59f2ca07aae53eb46e",
            "extends": {
                "id": "com.nikkorap.blueprinter",
                "version": "1.8.21"
            }
        }
    ]
}
```

Each manifest consists of:
- A single JSON object containing the mod parameters.
  - One of those definitions is the `artifacts` array which defines the released versions of the mod available for clients to install.

This structure allows forming the following relationships:
- Dependency chains.
- Incompatibility flags.
- Addon-to-Mod relationships (mods which add features to other mods).

---

To contribute your own Mod Manifests, please see [Contributing Manifests](#contributing-manifests).

To otherwise contribute to the project, please see [Contributing to NOMNOM](#contributing-to-nomnom).

For a raw overview of the Schema, please check [Validation Schema](./ValidationSchema.json).

For full detailed overview of the Schema, please continue reading.

# JSON Manifest Properties

## `id` <sub>`string` (<ins>Required</ins>)</sub>
> - Unique identifier for your mod.
> - It is recommended to keep this identifier consistent between this property, the file name of the JSON manifest, and the name of your mod's .DLL assembly (not including versioning in the assembly name if desired).
> ```json
> {
>     "id": "com.nikkorap.EditorPlus"
> }
> ```
> 
> > [!TIP]
> > To ensure your mod's identifier is unique, try one of the following:
> > - `<author>.<yourModName>`
> >   - *i.e., `aryx.f22`*
> > - `<topLevel>.<domain>.<yourModName>`
> >   - *i.e., `com.nikkorap.blueprinter`*
> > 
> > If your mod is not a **BepInEx Plugin**, but rather a content or utility add-on, it should conform to this structure instead:
> >
> > - `<parentModID>.<yourModName>`
> >   - *i.e., `NOBlackBox.VanillaTacviewAssetPack`*

## `displayName` <sub>`string` (<ins>Required</ins>)</sub>
> - Human-readable name of the mod.
> ```json
> {
>     "displayName": "Collimated HUD"
> }
> ```

## `description` <sub>`string` (<ins>Required</ins>)</sub>
> - A brief description of the mod.
> ```json
> {
>     "description": "The craziest mod anyone's ever seen..."
> }
> ```

## `isClientOrServer` <sub>`string<"Client"|"Server"|"Both">`</sub>
> - A string describing if the mod is client-side, server-side, or both.
> - The only valid entries are:
>   - `Client`
>   - `Server`
>   - `Both`
> ```json
> {
>     "isClientOrServer": "Client" 
> }
> ```

## `tags` <sub>`array[string]`</sub>
> - Relevant tags for your mod.
> ```json
> {
>     "tags": [
>         "QoL",
>         "aircraft",
>         "blueprinter"
>     ]
> }
> ```

## `urls` <sub>`array[object{"name": string, "url": string}]` (<ins>Required</ins>)</sub>
> - Array of objects where each object contains `name` and `url`.
> - At least one entry with `"name": "info"` and `"url"` set to a URL is required.
> - Additional entries are optional.
> ```json
> {
>     "urls": [
>         {
>             "name": "info",
>             "url": "https://github.com/clumzy/NO_Tactitools"
>         }
>     ]
> }
> ```

## `authors` <sub>`array[string]`</sub>
> - Array of strings containing authors of the mod.
> ```json
> {
>     "authors": [
>         "RehabRocket"
>     ]
> }
> ```

## `autoUpdateArtifacts` <sub>`string<"True"|"False">` (<ins>Required for auto-updating</ins>)</sub>
## `githubOwner` <sub>`string` (<ins>Required for auto-updating</ins>)</sub>
## `githubRepoName` <sub>`string` (<ins>Required for auto-updating</ins>)</sub>
> - You only need these if you want to set up automatic updating from your repository.
> - `githubOwner` and `githubRepoName` should be the same as in the URL for your repository.
> 
> > [!IMPORTANT]
> > `autoUpdateArtifacts` is a string and not a boolean... you have to set it to `"True"` or `"False"` instead of `true` or `false`.
> 
> ```json
> {
>     "autoUpdateArtifacts": "True",
>     "githubOwner": "clumzy",
>     "githubRepoName": "NO_Tactitools"
> }
> ```

## `imageUrl` <sub>`string`</sub>
## `imageHash` <sub>`string`</sub>
> - Exact URL for an image that represents the mod. This is used for display purposes only.
> - The image should be in JPEG or PNG format and at most 512x512, though as low as 128x128 should still look fine.
> - The image hash is a SHA256 hash with no prefix, just the raw output as a string.
>
> ```json
> {
>     "imageUrl": "https://github.com/SolarDyn/Assets/blob/main/icon/CollimatedHUD.png",
>     "imageHash": "a50838ad4f1c39eea75fbde2cb0f6769659dc69c25550478eff20a082e3f4d56"
> }
> ```

---

# JSON Manifest Artifact Property

## `artifacts` <sub>`array[object{...}]`</sub>
> Example artifact array containing one artifact object:
> ```json
> {
>     "artifacts": [
>         {
>             "category": "release",
>             "type": "plugin",
>             "fileName": "example-reference.7z",
>             "downloadUrl": "https://github.com/your/mod-repository/releases/download/1.0.2/example-reference.7z",
>             "hash": "sha256:aa7b70cad8b9b7638935d30ec3a60b697d8bbdf608f00d59f2ca07cce53eb569",
>             "version": "1.0.2",
>             "gameVersion": "0.34.2"
>         }
>     ]
> }
> ```

## `artifacts`.`category` <sub>`string<"release"|"pre-release">` (<ins>Required</ins>)</sub>
> - Mod category, one of the following:
>   - `"release"`: Stable release.
>   - `"pre-release"`: Unstable/pre-release.
> - This is to allow users to choose betwen which available versions they'd like to install.

## `artifacts`.`type` <sub>`string<"plugin"|"addon">` (<ins>Required</ins>)</sub>
> - Type of mod, one of the following:
>   - `"plugin"`: BepInEx plugin.
>   - `"addon"`: Add-on or extension for another mod.

## `artifacts`.`fileName` <sub>`string` (<ins>Required</ins>)</sub>
> - Name of the downloadable content file available in the latest release.
> - It is highly recommended to use an archive format such as `.zip` or `.7z`.

## `artifacts`.`downloadUrl` <sub>`string` (<ins>Required</ins>)</sub>
> - Direct download URL to the previous file in the latest release.

## `artifacts`.`hash` <sub>`string` (<ins>Required</ins>)</sub>
> - SHA256 hash of the file referenced by `fileName` and `downloadUrl`.
> - Format should be: `"sha256:<value>"`

## `artifacts`.`version` <sub>`string` (<ins>Required</ins>)</sub>
> - Mod version, same as the assembly version.
> - Must be easily parsable, such as `"0.0.0"`, `"0.0.0.0"`, `"v0.0.0"`, or `"v0.0.0.0"`.

## `artifacts`.`gameVersion` <sub>`string` (<ins>Required</ins>)</sub>
> - Latest game version the mod supports, such as `"0.34.2"`.

## `artifacts`.`extends` <sub>`object{"id": string, "version": string}`</sub>
> - Reference to the ID and version of the mod this mod extends if this mod is an addon.
> 
> > [!IMPORTANT]
> >
> > This is required if `"category": "addon"`.

> Example artifact array with `extends` object:
> ```json
> {
>     "artifacts": [
>         {
>             "category": "release",
>             "version": "1.0.4",
>             "gameVersion": "0.34.2",
>             "type": "addon",
>             "fileName": "Aryx_F22E_StrikeRaptor_1.0.4.dll",
>             "downloadUrl": "https://github.com/Aryx3D/Aryx_F22E_StrikeRaptor/releases/download/1.0.4/Aryx_F22E_StrikeRaptor_1.0.4.dll",
>             "hash": "sha256:c57b70ca9859b7638935d30ec3a60b697d8bbdf608f00d59f2ca07aae53eb46e",
>             "extends": {
>                 "id": "com.nikkorap.blueprinter",
>                 "version": "1.8.21"
>             }
>         }
>     ]
> }
> ```
>
## `artifacts`.`dependencies` <sub>`array[object{"id": string, "version": string}]`</sub>
> - Array of objects similar to the objects in `extends`.
> - Implement these to list mods as dependencies for your mod.
>
## `artifacts`.`incompatibilities` <sub>`array[object{"id": string, "version": string}]`</sub>
> - Array of objects similar to the objects in `extends`.
> - Implement these to list mods that your mod is incompatible with.

---

# Example Manifests
I pulled some manifests from random mods and included them here as reference material. 

*I did modify these a bit for consistency and brevity, but these are functionally identical to the originals and perfect to use as reference.*

If you need additional references, browse through the `modManifests` directory to check out other peoples' manifests. Quality and consistency may vary but they should all be functional.

```json
{
  "id": "com.dsr.nors",
  "displayName": "NORS - Nuclear Option Radio System",
  "description": "A realistic radio communication system for Nuclear Option.",
  "isClientOrServer": "Both",
  "tags": [
    "Utility",
    "QoL"
  ],
  "urls": [
    {
      "name": "info",
      "url": "https://github.com/NORehabRocket/NORS---Nuclear-Option-Radio-System"
    }
  ],
  "authors": [
    "RehabRocket"
  ],
  "autoUpdateArtifacts": "True",
  "githubOwner": "NORehabRocket",
  "githubRepoName": "NORS---Nuclear-Option-Radio-System",
  "artifacts": [
    {
      "fileName": "1NORS.zip",
      "version": "0.7.7",
      "category": "release",
      "type": "plugin",
      "gameVersion": "0.33",
      "downloadUrl": "https://github.com/NORehabRocket/NORS---Nuclear-Option-Radio-System/releases/download/0.7.7/1NORS.zip",
      "hash": "sha256:d4446afda611ee8200861afeedd414536e770389af874a95b2620704c9e383d7"
    },
    {
      "fileName": "1NORS.zip",
      "version": "0.7.4",
      "category": "release",
      "type": "plugin",
      "gameVersion": "0.33",
      "downloadUrl": "https://github.com/NORehabRocket/NORS---Nuclear-Option-Radio-System/releases/download/0.7.4/1NORS.zip",
      "hash": "sha256:07517b4283e9a757c3d30c0aceb72bd80628ec974779f8015fa4897f6f49e56f"
    }
  ]
}
```

```json
{
  "id": "NO_Tactitools",
  "displayName": "NO TactiTools",
  "description": "Nuclear Option Tactical Tools is an immersion and QoL focused gameplay mod.",
  "isClientOrServer": "Both",
  "tags": [
    "mod",
    "QoL"
  ],
  "urls": [
    {
      "name": "info",
      "url": "https://github.com/clumzy/NO_Tactitools"
    }
  ],
  "authors": [
    "\"George\""
  ],
  "autoUpdateArtifacts": "True",
  "githubOwner": "clumzy",
  "githubRepoName": "NO_Tactitools",
  "artifacts": [
    {
      "fileName": "NOTT_PR_0.7.2.zip",
      "version": "0.7.2",
      "category": "preRelease",
      "type": "plugin",
      "gameVersion": "0.33",
      "downloadUrl": "https://github.com/clumzy/NO_Tactitools/releases/download/0.7.2/NOTT_PR_0.7.2.zip",
      "hash": "sha256:a3dcb931850d638d14a7b147ee24ed2dfc4d90c8a19997cd68ae114fb0fa230e",
      "dependencies": [
        {
          "id": "no-autopilot-mod",
          "version": "5.5.3"
        },
        {
          "id": "BepInEx.ConfigurationManager",
          "version": "18.4.1"
        }
      ]
    }
  ]
}
```

```json
{
  "id": "com.nikkorap.blueprinter",
  "displayName": "Blueprinter",
  "description": "Core framework required for mods utilising blueprinter.",
  "isClientOrServer": "Both",
  "tags": [
    "mod",
    "blueprinter"
  ],
  "urls": [
    {
      "name": "info",
      "url": "https://github.com/nikkorap/NOBlueprinter-Releases/blob/main/README.md"
    },
    {
      "name": "2082 discord",
      "url": "https://discord.gg/qqMwyr2qxR"
    }
  ],
  "authors": [
    "nikkorap"
  ],
  "autoUpdateArtifacts": "True",
  "githubOwner": "nikkorap",
  "githubRepoName": "NOBlueprinter-Releases",
  "artifacts": [
    {
      "fileName": "Blueprinter_2.0.1.dll",
      "version": "2.0.1",
      "category": "release",
      "type": "plugin",
      "gameVersion": "0.34.2",
      "downloadUrl": "https://github.com/nikkorap/NOBlueprinter-Releases/releases/download/2.0.1/Blueprinter_2.0.1.dll",
      "hash": "sha256:a2cec71bda003824695b5c5b55879a50c4dad579a5597c795600428636f1f7ec"
    },
    {
      "fileName": "Blueprinter_2.0.0.dll",
      "version": "2.0.0",
      "category": "release",
      "type": "plugin",
      "gameVersion": "0.34.2",
      "downloadUrl": "https://github.com/nikkorap/NOBlueprinter-Releases/releases/download/2.0.0/Blueprinter_2.0.0.dll",
      "hash": "sha256:5d23fdeb275e07663685467e906dfdc01bc588a7ffb09f756e4fe85f7cc93016"
    },
    {
      "fileName": "Blueprinter_1.8.21.dll",
      "version": "1.8.21",
      "category": "release",
      "type": "plugin",
      "gameVersion": "0.34.2",
      "downloadUrl": "https://github.com/nikkorap/NOBlueprinter-Releases/releases/download/1.8.21/Blueprinter_1.8.21.dll",
      "hash": "sha256:a8dcef9315feac5be3cd30b33308f8b59196a53fca58aafdb663f12a68f9d465"
    }
  ]
}
```

## Contributing Manifests

Before you proceed, please ensure you familiarize yourself with [this manifest schema](#nomnom-schema).

1. Fork the repository
2. Create your own mod manifest(s) in the `modManifests` directory.
3. Submit a **Pull Request** to ```main``` branch
4. **Github Actions Workflow** will validate the schema and report if it's invalid.
5. If successful and no additional issues are found, an administrator will review and approve.

## Contributing to NOMNOM
1. Fork the repository (check fork all branches).
2. Check out the ```dev``` branch and utilise that for your changes.
3. Submit a **Pull Request** with a detailed explanation of your changes to the ```dev``` branch.
4. The request will be discussed and approved to merge if appropriate.

## Additional Guidelines
- In order for NOMNOM to automatically discover new releases for registered mods, they must be available as **release packages** on your GitHub repository..
  - If you use a different delivery method, you must submit a **pull request** to get new releases registered. Follow [these instructions.](#contributing-manifests)
- GitHub repositories for your mods should contain releases for **only one mod**. Do not put releases for multiple mods under one repository.
- If your release(s) contain multiple release assets, the first release asset on the list must be the one intended for NOMNOM.
  - GitHub lists them in alphabetical order, **including the file extension**.
  - The release asset must contain all the content for the mod to function, with exception for dependency or extension relationship.
- Your mod(s) must have a valid `version` that follows some acceptable versioning practice that is easy to parse (e.g. `1.2.3.4`, `v1.2.3.4`, `v2.0`, `2.0`, etc...). [See this for reference](https://learn.microsoft.com/en-us/dotnet/api/system.version?view=net-10.0#remarks).
- Your mod(s) must be compatible with BepInEx 5.
