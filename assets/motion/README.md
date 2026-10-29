# NameDrop motion reference

Adapted from the user-supplied Figma community file:
https://www.figma.com/design/bV9QctUEetDsPgfPnN5x5z/

Effect layers only: 53:2759 top_light, 53:2758 gradient, 53:2835 ripple.
Original SVG exports are preserved beside PNGs. PNGs are rendered with resvg to preserve the SVG Gaussian blur on Flutter/Windows/Android. No wallpaper, status bar, contact photos or Apple UI is included.

The reference uses prototype Smart Animate, not motion keyframe tracks. Read transitions: spring mass 1 / stiffness 56.46 / damping 15 for approach (~1302ms); mass 1 / stiffness 509 / damping 31.6 for reveal (~480ms); gentle return ~1022ms. Terax adapts these into an 1800ms one-shot edge wave and file reveal triggered by an authenticated offer. Transfer progress and verified completion remain real.
