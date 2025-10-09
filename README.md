# pfUI Hide Buffs

A pfUI extension addon that allows you to hide specific buffs from both the global buff display and player unitframe.

## Features

- Hide unwanted buffs by name
- Works with both pfUI's global buff frame and player unitframe
- Performance optimized with caching to prevent lag
- Native pfUI integration with GUI configuration

## Installation

1. Copy the `pfUI-hidebuffs` folder to your WoW AddOns directory
2. Reload your UI or restart WoW
3. The addon will automatically load with pfUI

## Usage

### Adding Buffs to Hide

1. Open pfUI configuration (`/pfui`)
2. Navigate to **Thirdparty** → **Hide Buffs**
3. Click the **[+]** button next to "Hidden Buff Names"
4. Enter the exact buff name (case-sensitive)
5. Click OK

### Removing Hidden Buffs

1. Open pfUI configuration
2. Navigate to **Thirdparty** → **Hide Buffs**
3. Click the dropdown next to "Hidden Buff Names"
4. Select the buff you want to show again
5. Click the **[-]** button

### Enable/Disable

Use the "Enable Hide Buffs" checkbox in the configuration to toggle the entire system on/off.

## Examples

Common buffs to hide:
- Glyph buffs: `Glyph of the Orca`, `Glyph of the Penguin`, etc.
- Tracking abilities: `Find Herbs`, `Track Humanoids`
- Shapeshifting side effects: `Heart of the Wild Effect`, passive Aura effects, etc.

## Performance

This addon is optimized for performance:
- Buff names are cached after first scan
- Configuration is only parsed when it changes
- No repeated tooltip scanning
- Minimal impact on framerate

## Technical Details

Works by hooking:
- pfUI's global buff frame OnEvent
- pfUI's unitframe RefreshUnit function

## Disclaimer

**USE AT YOUR OWN RISK**

- This addon is provided **AS-IS** with no warranty
- I do not provide support for this addon
- If you encounter issues, you can fork the code and modify it yourself
- Consider using AI tools (like Claude 4.5) to create your own version
- I maintain this addon only as long as I personally use it
- No guarantee of future compatibility or updates
- No responses to feature requests or support inquiries

## License

Feel free to modify, fork, or redistribute as needed.

## Credits

Built as an extension to pfUI for Vanilla/TBC WoW. Shagu is the GOAT, all hail the King.