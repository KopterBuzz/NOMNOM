# NOMNOM - Nuclear Option Managed & Neatly Organised Manifest

NOMNOM is a self-updating package manifest repository that you can use to source Nuclear Option Mod Packages.

## Current known Mod Manager projects that use NOMNOM:

- [NOMM - Nuclear Option Mod Manager](https://github.com/Combat787/NuclearOptionModManager/) - [DOWNLOAD](https://github.com/Combat787/NuclearOptionModManager/releases/latest)

- [Yellowcake Mod Manager](https://github.com/NaghDiefallah/Yellowcake) - [DOWNLOAD](https://github.com/NaghDiefallah/Yellowcake/releases/latest)


## How to Add your Nuclear Option Mod to NOMNOM

NOMNOM is able to automatically pick up new releases for Mods that it already knows about.

However, there are some basic requirements in order for NOMNOM to keep itself up to date in regards to the latest available version of your Mod(s):
 - your Mod releases must be available on GitHub as a RELEASE PACKAGE
 - your Mod release must have a valid tagName that follows good versioning (e.g. 1.2.3.4 or v1.2.3.4 or v2.0 or 2.0 etc)

 This is not directly related to the above, but at the moment Mod Manager software that depends on NOMNOM expects the following criteria also:
 - your Mod(s) must work with BepInEx 5
