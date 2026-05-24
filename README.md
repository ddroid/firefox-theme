# Firefox GNOME Theme (Custom Version)

A GNOME theme for Firefox with Catppuccin Macchiato color scheme.
![Screenshot of the theme](screenshot.png)
## Installation

### Quick Install (Recommended)

1. Clone this repository:
   ```bash
   git clone https://github.com/ddroid/firefox-gnome-theme.git
   cd firefox-gnome-theme
   ```

2. Run the auto-install script:
   ```bash
   ./scripts/auto-install.sh
   ```

3. Restart Firefox

### Manual Install

1. Find your Firefox profile directory:
   - Open Firefox and go to `about:support`
   - Click "Open Directory" next to "Profile Directory"

2. In your profile directory, create a `chrome` folder:
   ```bash
   mkdir -p chrome
   cd chrome
   ```

3. Clone this theme into the chrome folder:
   ```bash
   git clone https://github.com/ddroid/firefox-gnome-theme.git
   ```

4. Create user CSS files if they don't exist:
   ```bash
   [[ -s userChrome.css ]] || echo >> userChrome.css
   [[ -s userContent.css ]] || echo >> userContent.css
   ```

5. Import the theme at the beginning of your CSS files:
   ```bash
   sed -i '1s/^/@import "firefox-gnome-theme\/userChrome.css";\n/' userChrome.css
   sed -i '1s/^/@import "firefox-gnome-theme\/userContent.css";\n/' userContent.css
   ```

6. Link the configuration file:
   ```bash
   cd ..
   ln -fs chrome/firefox-gnome-theme/configuration/user.js user.js
   ```

7. Restart Firefox

## Required Firefox Preferences

Make sure these are enabled in `about:config`:

- `toolkit.legacyUserProfileCustomizations.stylesheets` - Required for custom CSS
- `svg.context-properties.content.enabled` - Required for proper icon colors

## Theme Features

This custom version includes:
- Catppuccin Macchiato color scheme
- GNOME Adwaita-style interface
- Dark and light theme support
- Improved card styling with shadows

## Updates

To update the theme, pull the latest changes and restart Firefox:
```bash
cd firefox-gnome-theme
git pull
```

## Uninstall

1. Remove the `chrome` folder from your Firefox profile directory
2. Remove the theme preferences from `user.js` in your profile directory
