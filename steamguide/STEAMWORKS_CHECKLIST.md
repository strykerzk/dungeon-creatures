# Steam Publication Checklist

Complete this checklist before submitting your game to Steam for publication.

## Pre-Development Setup

### Steamworks Account & Registration
- [ ] Created Steamworks partner account
- [ ] Verified company information
- [ ] Agreed to Steam Distribution Agreement
- [ ] Set up payment information
- [ ] Obtained unique App ID from Steamworks dashboard
- [ ] Created `steam_appid.txt` with correct App ID

### Development Environment
- [ ] Installed GodotSteam addon (matches Godot 4.6)
- [ ] Built/compiled GodotSteam for your platform(s)
- [ ] Added GodotSteam to project `addons/` folder
- [ ] Enabled GodotSteam plugin in Project Settings
- [ ] Updated project.godot with Steam settings (see STEAM_CONFIGURATION.md)

## Code Implementation

### Core Steam Integration
- [ ] Created SteamManager.gd (based on STEAM_MANAGER.gd template)
- [ ] Registered SteamManager as autoload
- [ ] Verified Steam initialization on startup
- [ ] Tested Steam initialization with debug prints
- [ ] Confirmed user ID and username are retrieved
- [ ] Error handling implemented for Steam initialization failure

### Achievements System
- [ ] Created SteamAchievements.gd (based on STEAM_ACHIEVEMENTS.gd template)
- [ ] Defined all achievement IDs in ACHIEVEMENTS dict
- [ ] Achievements match Steamworks backend configuration
- [ ] Connected game events to achievement unlock methods
- [ ] Tested achievement unlocking locally
- [ ] Verified achievements sync to Steam
- [ ] Implemented achievement UI notifications (optional)

### Statistics & Leaderboards
- [ ] Identified statistics to track (kills, time, etc.)
- [ ] Added statistics definitions to Steamworks
- [ ] Implemented statistics tracking in gameplay code
- [ ] Statistics correctly sync to Steam
- [ ] (Optional) Leaderboards configured and tested
- [ ] (Optional) Rich presence implemented

### Steam Features
- [ ] Cloud saves implemented (if applicable)
- [ ] Steam overlay compatibility verified
- [ ] Steam Controller support tested
- [ ] Game overlay shortcuts configured
- [ ] In-game links to store page implemented

## Testing

### Local Testing
- [ ] Steam API initializes correctly on startup
- [ ] steam_appid.txt present in build directory
- [ ] Debug logs show Steam connection successful
- [ ] All achievements unlock and sync properly
- [ ] Statistics track and sync correctly
- [ ] Cloud saves upload and download correctly
- [ ] No Steam errors in console

### Platform-Specific Testing
- [ ] **Windows (64-bit)**
  - [ ] Builds without errors
  - [ ] Steam initializes on startup
  - [ ] All features functional
  - [ ] Performance acceptable
  
- [ ] **macOS** (if supporting)
  - [ ] Code signed correctly
  - [ ] Notarization completed
  - [ ] Steam initializes properly
  - [ ] All features functional
  
- [ ] **Linux** (if supporting)
  - [ ] Builds with correct glibc version
  - [ ] Steam initializes properly
  - [ ] All features functional

### Feature Testing
- [ ] Achievements unlock without issues
- [ ] Leaderboard scores submit correctly
- [ ] Cloud saves work (upload and download)
- [ ] Steam overlay appears correctly
- [ ] Steam Controller inputs mapped properly
- [ ] No crashes related to Steam API calls
- [ ] Game works offline (graceful degradation)

### Beta Branch Testing
- [ ] Created beta build depot in Steamworks
- [ ] Uploaded build to beta branch
- [ ] Tested on beta branch as regular user
- [ ] All features work on beta branch
- [ ] No unexpected errors or crashes
- [ ] Performance is acceptable

## Steamworks Configuration

### Application Settings
- [ ] Application name finalized
- [ ] Application type set to "Game"
- [ ] Supported platforms selected (Windows/macOS/Linux)
- [ ] Supported languages configured

### Store Listing
- [ ] Short description written (10-30 words)
- [ ] Full description written (engaging and informative)
- [ ] Screenshots captured (minimum 5, recommended 10)
  - [ ] Images are 1920x1080 or higher
  - [ ] Images showcase key gameplay features
- [ ] Trailer/video uploaded (recommended)
- [ ] Cover art created (600x900 pixels)
- [ ] Hero image created (1920x622 pixels)
- [ ] Logo created (600x300 pixels)

### Age Ratings
- [ ] Age rating completed (ESRB, PEGI, etc.)
- [ ] Content warnings displayed if needed
- [ ] Game marked as appropriate for all ages (if applicable)

### Release Information
- [ ] Release date scheduled
- [ ] Release state set (Coming Soon → Released)
- [ ] Pricing determined (free or $X.XX)
- [ ] Regional pricing configured (if applicable)

### Build Configuration
- [ ] Build depots created for each platform
- [ ] Builds uploaded to depots
- [ ] Builds associated with correct depots
- [ ] Main branch default builds set
- [ ] Build manifests verified

## Pre-Launch Checklist

### Quality Assurance
- [ ] Game is stable (minimal crashes)
- [ ] Frame rate acceptable on target hardware
- [ ] No major gameplay bugs
- [ ] Tutorial/onboarding works correctly
- [ ] Audio levels balanced
- [ ] Text readable at various resolutions
- [ ] No placeholder content left in

### Legal & Compliance
- [ ] Game meets Steam's content policy
- [ ] No third-party copyright violations
- [ ] End-user license agreement (EULA) compliant
- [ ] Privacy policy clear about data collection
- [ ] No prohibited content (per Steam rules)

### Documentation
- [ ] README updated with Steam features
- [ ] System requirements documented
- [ ] Known issues documented
- [ ] Support contact information available
- [ ] Changelog prepared

### Final Build Verification
- [ ] Final build uploaded to Steam
- [ ] Build successfully downloaded and tested
- [ ] All features work in final build
- [ ] No debug/test content in final build
- [ ] Achievements work in final build
- [ ] Statistics and leaderboards work

## Launch Preparation

### Pre-Launch Marketing (Optional)
- [ ] Store page optimized for discoverability
- [ ] Wishlist campaign (if applicable)
- [ ] Community channels set up (Discord, forum, etc.)
- [ ] Press materials prepared
- [ ] Launch announcement prepared

### Launch Day
- [ ] Set official release time
- [ ] Notify community of release
- [ ] Monitor for issues post-launch
- [ ] Support team ready for feedback
- [ ] Be prepared to patch if critical issues arise

## Post-Launch

### Monitoring & Support
- [ ] Monitor crash reports from Steamworks dashboard
- [ ] Review player feedback and reviews
- [ ] Track achievements unlock rates
- [ ] Monitor concurrent player count
- [ ] Track crash logs for bugs
- [ ] Update game if critical issues found
- [ ] Respond to community feedback

### Updates & Patches
- [ ] Plan update schedule (if applicable)
- [ ] Test updates thoroughly before release
- [ ] Communicate patch notes clearly
- [ ] Continue supporting achievements and stats

## Resources & References

- **Steamworks Dashboard**: https://partner.steamgames.com/
- **GodotSteam GitHub**: https://github.com/GodotSteam/GodotSteam
- **Steamworks Documentation**: https://partner.steamgames.com/doc/home
- **Steam Policies**: https://partner.steamgames.com/doc/gettingstarted/onboarding
- **Godot Export Docs**: https://docs.godotengine.org/en/stable/tutorials/export/index.html

## Notes

- Replace all "YOUR_APP_ID" placeholders with your actual Steam App ID
- Keep `steam_appid.txt` in build directory but don't commit real IDs to public repos
- Test thoroughly on all supported platforms before submission
- Budget 2-4 weeks for the entire process
- Be prepared to address feedback or requested changes from Steam review team

---

**Last Updated**: When preparing for Steam publication
**Status**: [ ] Complete [ ] In Progress [ ] Not Started
