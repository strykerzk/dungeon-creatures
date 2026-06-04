# Steam Integration Guide for dungeon-creatures

This folder contains reference files and guides for integrating Steam's API and tools into the dungeon-creatures project. Use this as a reference when preparing the project for Steam publication.

## Contents

- **STEAM_SETUP.md** - Step-by-step setup instructions
- **STEAM_CONFIGURATION.md** - Configuration and project settings
- **STEAM_MANAGER.gd** - Template autoload script for Steam integration
- **STEAM_ACHIEVEMENTS.gd** - Template for achievements implementation
- **steam_appid.txt** - Placeholder Steam App ID file
- **STEAMWORKS_CHECKLIST.md** - Publishing checklist

## Overview

When you're ready to publish on Steam, follow these steps in order:

1. Complete the Steamworks registration and obtain your App ID
2. Review and implement the Steam Manager template
3. Configure project settings using STEAM_CONFIGURATION.md
4. Implement achievements and other Steam features
5. Build and test using the checklist
6. Submit to Steam

## Quick Start

1. Replace placeholders in `steam_appid.txt` with your actual App ID
2. Copy `STEAM_MANAGER.gd` to your project's autoload or scripts directory
3. Register it in project.godot as an autoload
4. Begin integrating Steam features as outlined in the template files

## Resources

- [GodotSteam GitHub](https://github.com/GodotSteam/GodotSteam)
- [Steamworks Documentation](https://partner.steamgames.com/doc/home)
- [Godot Engine Documentation](https://docs.godotengine.org/)

---

**Note**: These are template files meant for future reference. Implement when you have a working demo ready for Steam publication.
