# Steam Setup Guide

Step-by-step instructions for integrating Steam into dungeon-creatures.

## Phase 1: Preparation (Before Coding)

### 1. Steamworks Registration
- [ ] Create a Steamworks partner account
- [ ] Complete company information verification
- [ ] Set up payment information
- [ ] Agree to Steam Distribution Agreement

### 2. Get Your App ID
- [ ] Log into Steamworks dashboard
- [ ] Create a new application
- [ ] Note your unique **App ID** (e.g., 480 for Valve's Spacewar)
- [ ] Save this in `steam_appid.txt` in your project root

### 3. Set Up GodotSteam

```bash
# Clone GodotSteam repository
git clone https://github.com/GodotSteam/GodotSteam.git

# Navigate to the repository
cd GodotSteam

# Compile for Godot 4.6
# Follow the platform-specific build instructions in GodotSteam README
# You'll need to match your Godot version (4.6)

# Copy compiled binaries to your project
cp -r addons/godotsteam/ /path/to/dungeon-creatures/addons/
```

## Phase 2: Project Configuration

### 1. Add GodotSteam to Your Project
- [ ] Copy `addons/godotsteam` folder to your project
- [ ] Restart Godot Editor
- [ ] Enable the plugin in Project Settings > Plugins

### 2. Update project.godot
- [ ] Add Steam autoload (see STEAM_CONFIGURATION.md)
- [ ] Configure Steam settings
- [ ] Update export templates

### 3. Create steam_appid.txt
```
YOUR_APP_ID_HERE
```
Place this file in your project root directory.

## Phase 3: Code Integration

### 1. Initialize Steam Manager
- [ ] Copy `STEAM_MANAGER.gd` to your project
- [ ] Register as an autoload in project.godot
- [ ] Test initialization with debug prints

### 2. Implement Core Features
- [ ] Achievements system (STEAM_ACHIEVEMENTS.gd)
- [ ] Stats tracking
- [ ] Leaderboards (if applicable)
- [ ] Cloud saves
- [ ] Rich presence

### 3. Update Existing Systems
- [ ] Integrate with NetworkManager for Steam networking
- [ ] Update AudioRecorder for Steam compatibility
- [ ] Add Steam controller support to input handling
- [ ] Test Steam overlay compatibility

## Phase 4: Testing

### 1. Local Testing
- [ ] Build the game
- [ ] Run with `steam_appid.txt` present
- [ ] Verify Steam API initialization
- [ ] Test each Steam feature locally

### 2. Beta Testing on Steam
- [ ] Create a beta branch in Steamworks
- [ ] Upload build to beta
- [ ] Test achievements, leaderboards, cloud saves
- [ ] Verify on different systems/platforms

### 3. Quality Assurance
- [ ] Run through STEAMWORKS_CHECKLIST.md
- [ ] Test on Windows, macOS, Linux (if supporting)
- [ ] Verify DRM protection
- [ ] Check overlay compatibility

## Phase 5: Submission

### 1. Store Listing
- [ ] Write game description
- [ ] Create store screenshots/artwork
- [ ] Set age rating
- [ ] Define supported platforms and languages

### 2. Build Upload
- [ ] Upload final build via Steamworks
- [ ] Set as default build
- [ ] Verify on Steam's testing branch

### 3. Launch
- [ ] Schedule release date
- [ ] Submit for review (if required)
- [ ] Monitor for any issues after launch

## Troubleshooting

### Steam API Not Initializing
- [ ] Check steam_appid.txt exists in project root
- [ ] Verify App ID is correct
- [ ] Ensure GodotSteam addon is properly installed
- [ ] Check Godot console for error messages

### Build Failures
- [ ] Verify Godot version matches GodotSteam build
- [ ] Rebuild export templates with Steam support
- [ ] Check for missing dependencies

### Platform-Specific Issues
- Windows: Verify 64-bit build, MSVC runtime
- macOS: Check code signing, hardened runtime
- Linux: Verify glibc version compatibility

## Resources

- GodotSteam Documentation: https://github.com/GodotSteam/GodotSteam
- Steamworks Partner Documentation: https://partner.steamgames.com/doc/home
- Godot Export Documentation: https://docs.godotengine.org/en/stable/tutorials/export/index.html
