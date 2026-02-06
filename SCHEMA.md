# NOMNOM Schema

The manifest items consist of two main models:
- Mod
- Artifact

Mod is the main manifest catlog item, which has Artifacts, that are versioned representations of the actual content for the game.

For Example:
- Mod Xyz.ExampleMod
    - Xyz.ExampleMod-1.11.0
    - Xyz.ExampleMod-1.10.1
    - Xyz.ExampleMod-1.9.9

This structure allows forming the following relationships:
- Dependency Chains
- Incompatibility Flags
- Add-On-Mod Relationships (such as Voice Packs for WSO Yappinator, or Tacview Asset Packs for modded content, for example)

To contribute your own Mod Manifests, please see [HOW TO CONTRIBUTE MOD MANIFESTS](#how-to-contribute-mod-manifests)

To otherwise contribute to the project, please see [HOW TO CONTRIBUTE ANYTHING ELSE](#how-to-contribute-anything-else)

For a raw overview of the Schema, please check [Validation Schema.](./ValidationSchema.json)

For full detailed overview of the Schema, please continue reading.

## Mod Object Properties

### id

- REQUIRED
- Format: string
- IDEALLY, This should be the AssemblyName of the BepInEx Plugin DLL
- If the Mod is not a BepInEx Plugin, but rather a content or utility, it should conform to this structure:

    ```"ModAssemblyName.UniqueRelevantString"```

    e.g

    ```"NOBlackBox.VanillaTacviewAssetPack"```

### displayName

- REQUIRED
- Format: string
- This is the Human Readable Name of the Mod

### description

- REQUIRED
- Format: string
- This is a brief descritpion of what the Mod does

### tags

- Format: array of strings
- different tags, sucha as "QoL","Art","Aircraft","Terrain","Flavor","Server"

### urls

- REQUIRED
- Format: Array of Objects
```
name : category of the url. an "info" url is mandatory, other arbitrary category names can be added
url : the actual URL
```
- You can attach urls relevant to your mod or yourself as the author.


### authors

- Format: array of strings
- this should be a list of authors who created the Mod

### githubOwner

- REQUIRED IF:
     YOU WANT YOUR MOD MANIFEST TO BE AUTO-UPDATED BY NOMNOM
- Format: string
- the name of GitHub Account or GitHub Organization that owns the repository where Releases are published

### githubRepoName

- REQUIRED IF:
     YOU WANT YOUR MOD MANIFEST TO BE AUTO-UPDATED BY NOMNOM
- Format: string
- the name of GitHub repository where Releases are published

### autoUpdateArtifacts

- REQUIRED IF:
     YOU WANT YOUR MOD MANIFEST TO BE AUTO-UPDATED BY NOMNOM
- Format: string
- "True" if you want Auto Updates Enabled, "False" if Disabled

## Artifact Object Properties

### type

- REQUIRED
- Format: string
- type of Mod. currently considering following types to be supported:
    - plugin: BepInEx Plugin
    - addOn: Add-On or extension for another Mod, such as a voice or texture pack etc.

### fileName

- REQUIRED
- Format: string
- name of the actual downloadable content file. Should be an archive, such as zip, rar, 7z.

### gameVersion

- REQUIRED
- Format: Version as string
- This is the latest game version the mod supports e.g. ```"0.32"```

### version

- REQUIRED
- Format: Version as string
- THIS MUST MATCH THE VERSION IN THE DLL IN ITS METADATA IF Artifact Type = MOD

### category

- REQUIRED
- Format: string
- This is the category if the release e.g. Release or Pre-Release
- This is to allow users to optionally download a perhaps Unstable Pre-Release, or get the latest stable version.

### extends

- REQUIRED IF
    - CATEGORY IS addOn
- Format: Object
```
id : Mod id as string
version : Mod version as string
```
id must be the known Mod id of the mod this extends, as seen in the Manifest

version must be the minimum version this extension is compatible with

### dependencies

- REQUIRED IF
    - MOD HAS DEPENDENCIES
- Format: Array of Objects
```
id : Mod id as string
version : Mod version as string
```
id must be the known Mod id of the mod this depends on, as seen in the Manifest

version must be the minimum version this extension is compatible with

### incompatibilities

- REQUIRED IF
    - MOD IS KNOWN TO BE INCOMPATIBLE WITH OTHER MODS
- Format: Array of Objects
```
id : Mod id as string
version : Mod version as string
```
id must be the known Mod id of the mod this is incompatible with, as seen in the Manifest

version must be the latest known version this mod is incompatible with

## HOW TO CONTRIBUTE MOD MANIFESTS

Before you proceed, please ensure you familiarize yourself with the [manifest structure](#nomnom-schema), including [mod](#mod-object-properties) and [artifact](#artifact-object-properties) object properties.

1. Fork the repository
2. Create your own mod manifest(s) based on the schema described above
3. Submit a Pull Request to ```main``` branch
4. Github Actions Workflow will validate the Schema and Content, then declare the Pull Request allowed to merge if successful
5. A Human will review and approve the merge if no additional issues found

## HOW TO CONTRIBUTE ANYTHING ELSE
1. Fork the repository (check fork all branches)
2. Check out the ```dev``` branch to make sure you are working on the correct branch
3. Submit a Pull Request WITH DETAILED EXPLANATION of your changes to the ```dev``` branch
4. Your Pull Request will be discussed and approved to merge if appropriate