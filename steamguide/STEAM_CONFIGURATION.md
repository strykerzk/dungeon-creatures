# Steam Configuration Guide

Configuration settings and project.godot updates needed for Steam integration.

## project.godot Updates

Add the following sections to your `project.godot` file:

### Autoload Registration

```ini
[autoload]

# Existing autoloads
CreatureManager="*uid://c0bdb53vnj3gi"
NetworkManager="*uid://bhknutagcttrd"
StageManager="*uid://bckuj40t1oi5f"
AudioRecorder="*uid://c1nwqo86wknlk"

# Add Steam Manager
Steam="*res://addons/godotsteam/Steam.gd"
SteamManager="*res://scripts/SteamManager.gd"
```

### Application Settings

```ini
[application]

# Existing settings
config/name="dungeon-creatures"
run/main_scene="uid://b8hp5sprfrkea"
config/features=PackedStringArray("4.6", "Forward Plus")
run/max_fps=240
config/icon="res://icon.svg"

# Add Steam features to supported features
config/features=PackedStringArray("4.6", "Forward Plus", "Steam")
```

### Export Settings for Steam

#### Windows Export

```ini
[export]

# Steam settings
application/id="YOUR_APP_ID_HERE"
application/family_name="Dungeon Creatures"
application/product_name="Dungeon Creatures"

# Steam-specific export settings
steamworks/enabled=true
steamworks/app_id=YOUR_APP_ID_HERE
steamworks/use_steam_client=true
steamworks/drm_enabled=true
```

#### macOS Export

```ini
[export.macos]

steamworks/enabled=true
steamworks/app_id=YOUR_APP_ID_HERE
code_sign_identity="Developer ID Application"
notarization/enabled=true
```

#### Linux Export

```ini
[export.linux]

steamworks/enabled=true
steamworks/app_id=YOUR_APP_ID_HERE
```

## Environment Variables

Set these when building for Steam:

```bash
# Linux/macOS
export SteamAppId=YOUR_APP_ID_HERE

# Windows
set SteamAppId=YOUR_APP_ID_HERE
```

## Build Export Templates

You'll need to rebuild export templates with Steam support:

```bash
# Clone Godot Engine matching your version (4.6)
git clone -b 4.6 https://github.com/godotengine/godot.git
cd godot

# Build export templates
# Follow official Godot build instructions
# Ensure Steamworks SDK is properly linked during compilation

# After successful build, import templates into Godot:
# Project > Project Settings > Export > Install Android Build Template
# (or appropriate platform)
```

## Input Device Configuration

### Add Steam Controller Support

```ini
[input]

# Existing input mappings
up={...}
down={...}
left={...}
right={...}

# Steam controller should automatically work with mapped inputs
# Consider adding additional Steam-specific actions if needed
```

### Steam Input Mapping

Steam will automatically map controller inputs to your existing input map. If you want to add Steam-specific inputs:

```gdscript
# In your input handling code
if Input.is_action_pressed("ui_accept"):
    # Works with keyboard, gamepad, AND Steam Controller
    pass

# For Steam-specific features:
if Steam.isSteamControllerConfigurationAvailable():
    # Handle Steam Controller specific input
    pass
```

## Display Settings

### Overlay Compatibility

```ini
[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"

# Ensure overlay can render properly
window/vsync_mode=1  # Adaptive vsync recommended
```

## Audio Configuration

Your existing audio settings should work with Steam, but verify:

```ini
[audio]

driver/enable_input=true

# Add Steam audio integration if using Steam Voice
# This is optional but recommended for multiplayer
```

## Steam Configuration File (steam_appid.txt)

Create this file in your project root and in your build directory:

```
YOUR_APP_ID_HERE
```

**Important**: Do NOT commit this file with a real App ID to public repositories. Use a placeholder and replace during build.

## Steamworks Partner Settings

These are configured in the Steamworks dashboard, not in Godot:

### Basic Application Settings
- [ ] Set supported platforms (Windows, macOS, Linux)
- [ ] Configure supported languages
- [ ] Set age rating
- [ ] Define application type (Game)

### Release Settings
- [ ] Set release date
- [ ] Configure release state (Coming Soon → Released)
- [ ] Set pricing

### Build Configuration
- [ ] Create build depots for each platform
- [ ] Associate builds with depots
- [ ] Configure branching (Main, Beta, Testing)

## Testing Configuration

### Debug Mode

Enable debug logging during development:

```gdscript
# In SteamManager.gd during initialization
Steam.steamEnableLogging(true)
Steam.setLogFunction(func(severity, message):
    print("[Steam] %s: %s" % [severity, message])
)
```

### Local Testing without Steam

For testing without a Steamworks account:

```gdscript
# In SteamManager.gd
var is_steam_running = Steam.steamInit()
if not is_steam_running:
    print("Steam not running - using offline mode")
    # Handle offline/demo mode
```

## Performance Optimization

### Memory and CPU

```ini
[rendering]

# Steam overlay works better with these settings
global_illumination/gi/use_half_resolution=true
textures/vram_compression/import_etc2_astc=true
```

### Network

If using Steam Networking:

```gdscript
# Recommended settings in SteamManager
Steam.setMaxTicksPerSecond(60)  # Match your game's tick rate
```

## Security

### DRM and Protection

Steam provides DRM protection by default. Ensure:

- [ ] Build is uploaded through Steamworks (not direct download)
- [ ] steam_appid.txt is present in build directory
- [ ] No external launchers are wrapping the game executable

### Achievements and Statistics

All achievements and stats are server-side and protected by Steam.

## Verification Checklist

- [ ] All autoloads registered correctly
- [ ] steam_appid.txt exists with correct App ID
- [ ] Export templates rebuilt with Steam support
- [ ] All input mappings function with Steam Controller
- [ ] Audio driver compatible with Steam overlay
- [ ] Display settings compatible with overlay rendering
- [ ] DRM enabled in export settings
- [ ] Steamworks dashboard configured for your platforms
