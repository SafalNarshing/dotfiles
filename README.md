# dotfiles

Hyprland desktop for an **ASUS ROG Zephyrus G16 (GU605)** running Arch Linux.

Violet-on-glass theme across the bar, launcher, notifications and lock screen.
Everything here is live-linked — `~/.config/hypr` and friends are symlinks into
this repo, so edits land in git immediately.

```
  Compositor   Hyprland 0.56 (Lua config)
  Bar          Waybar          Launcher   Rofi
  Notifs       SwayNC          Lock       Hyprlock
  Wallpaper    Hyprpaper       Idle       Hypridle
  Terminal     Kitty           Shell      Bash
```

---

## Install

```bash
git clone https://github.com/SafalNarshing/dotfiles ~/Projects/dotfiles
cd ~/Projects/dotfiles && ./install.sh
```

`install.sh` backs up anything already in place to `*.bak` before linking, so
it is safe to re-run.

---

## Keybindings

`SUPER` is the Windows key.

### Launching

| Keys | Action |
| --- | --- |
| `SUPER` `Q` | Terminal (kitty) |
| `SUPER` `R` | App launcher (rofi) |
| `SUPER` alone | App launcher — release-bind |
| `SUPER` `E` | File manager (nautilus) |
| `SUPER` `SHIFT` `E` | Terminal file manager (yazi) |
| `SUPER` `SHIFT` `M` | Monitor config TUI (hyprmoncfg) |
| `SUPER` `C` | Close window |

### Workspaces

| Keys | Action |
| --- | --- |
| `SUPER` `1`–`0` | Go to workspace |
| `SUPER` `SHIFT` `1`–`0` | Move window to workspace |
| `SUPER` `CTRL` `←` `→` | Previous / next existing workspace |
| `SUPER` `CTRL` `↑` | Next empty workspace — "new desktop" |
| `SUPER` `CTRL` `SHIFT` `←` `→` | Carry window to neighbouring workspace |
| `SUPER` scroll | Cycle workspaces |
| `SUPER` `S` | Toggle scratchpad |
| `SUPER` `ALT` `S` | Move window to scratchpad |

### Windows

| Keys | Action |
| --- | --- |
| `SUPER` `←` `→` `↑` `↓` | Focus by direction |
| `SUPER` `V` | Toggle floating |
| `SUPER` `P` | Pseudo-tile |
| `SUPER` `J` | Toggle split direction |
| `SUPER` + drag LMB / RMB | Move / resize |

### Session

| Keys | Action |
| --- | --- |
| `SUPER` `L` | Lock now |
| `SUPER` `ESC` | Power menu |
| `SUPER` `M` | Exit Hyprland |
| Lid close | Lock |

### Capture & clipboard

| Keys | Action |
| --- | --- |
| `SUPER` `SHIFT` `S` | Region screenshot → clipboard |
| `SUPER` `SHIFT` `V` | Clipboard history |

### Media

| Keys | Action |
| --- | --- |
| `XF86MonBrightness` `↑` `↓` | Brightness — gamma, see notes |
| `XF86Audio` `Raise` `Lower` `Mute` | Volume |
| `XF86Audio` `Play` `Next` `Prev` | Playback |

---

## Packages

### Core desktop

| Package | Purpose |
| --- | --- |
| `hyprland` | Wayland compositor. Uses the **Lua** config format |
| `waybar` | Status bar |
| `rofi-wayland` | App launcher and power menu |
| `swaync` | Notification daemon **and** notification centre |
| `hyprpaper` | Wallpaper daemon |
| `hyprlock` | Lock screen |
| `hypridle` | Idle timeouts, lock on lid close |
| `kitty` | Terminal, GPU-accelerated |
| `xdg-desktop-portal-hyprland` | Screen sharing and screenshot portal |
| `hyprpolkitagent` | Polkit authentication prompts |

### Utilities

| Package | Purpose |
| --- | --- |
| `grim` + `slurp` | Screenshot capture and region selection |
| `wl-clipboard` | `wl-copy` / `wl-paste` |
| `cliphist` | Clipboard history store |
| `wl-gammarelay-rs` | **Brightness** via gamma ramps — see notes |
| `playerctl` | Media key handling |
| `pavucontrol` | Audio mixer |
| `blueman` + `bluez-utils` | Bluetooth |
| `nautilus` | Graphical file manager |
| `yazi` | Terminal file manager |
| `btop` | System monitor |
| `fastfetch` | Shell greeter |
| `network-manager-applet` | Provides `nm-connection-editor` |

### Hardware

| Package | Purpose |
| --- | --- |
| `nvidia-open` + `nvidia-utils` | RTX 4070 driver — versions must match |
| `intel-media-driver` | **Video decode** on the Intel iGPU — see notes |
| `asusctl` | Fan curves, battery charge limit, Aura |
| `rog-control-center` | ASUS GUI control panel |

### Fonts

| Package | Purpose |
| --- | --- |
| `ttf-jetbrains-mono-nerd` | UI and terminal font, supplies all glyph icons |
| `ttf-nerd-fonts-symbols` | Icon fallback |

---

## Notes

Things about this machine that cost real time to work out. Read before editing.

### The panel is OLED — there is no backlight

Every backlight method is a silent no-op: `brightnessctl`, `acpi_backlight=`,
`i915.enable_dpcd_backlight`, `nvidia_wmi_ec_backlight`, `asusctl backlight`.
They report success and change nothing.

Brightness is **`wl-gammarelay-rs`**, which adjusts the gamma ramp over D-Bus.
`scripts/brightness.sh` wraps it because the raw `UpdateBrightness` call does
not clamp — holding the key drives past 1.0 or below 0.0 and blacks the screen.

> The D-Bus **service** is `rs.wl-gammarelay` (hyphen), the **interface** is
> `rs.wl.gammarelay` (all periods). They are deliberately different.

### Hyprland uses the Lua config, not `.conf`

Almost every guide online is for the legacy format and will not work.

| Legacy | Here |
| --- | --- |
| `bind = SUPER, R, exec, rofi` | `hl.bind("SUPER + R", hl.dsp.exec_cmd("rofi"))` |
| `hyprctl dispatch exit` | `hyprctl dispatch 'hl.dsp.exit()'` |
| `hyprctl dispatch dpms off` | `hyprctl dispatch 'hl.dsp.dpms("off")'` |

`hl.dsp.dpms()` does **not** validate its argument — anything that is not
`"on"` turns the displays off.

Verify any change with `Hyprland --verify-config` before reloading.

### hyprpaper 0.8.x changed its config format

`preload =` / `wallpaper = ,path` is gone. It parses without error and
silently draws nothing, logging only `Monitor eDP-1 has no target`. The
current format is a `wallpaper { }` block, and paths must be **absolute** —
`~` is not expanded.

### swaync themes through `:root` variables

Short selectors like `.notification { background: … }` are overridden by the
shipped stylesheet's longer chains and do nothing. Override the `:root` custom
properties instead, or match the full chain.

### hyprlock hides the password box by default

`fade_on_empty` defaults to `true`, so an empty field renders as fully
invisible — even at full opacity. Used deliberately here for the macOS-style
reveal-on-typing. Also `$DESC` reads the GECOS field, which is empty on a
typical Arch account; use `$USER`.

### Waybar CSS is order-sensitive

`.active`, `:hover`, `.occupied` and `.visible` all have identical specificity,
so source order alone decides the winner. Required order in `style.css` is
`occupied → active → hover → urgent`. Appending a new state rule at the bottom
will silently override the focused workspace.

Workspace dots also need `font-size: 0` on `#workspaces button label` — the
label reserves a full line box even when empty, which is what makes dots render
as stretched capsules.

### Video decode must stay on the iGPU

Hyprland advertises the Intel render node for dmabuf. Decoding on the dGPU
produces `eglCreateImage failed … EGL_BAD_MATCH` on every H.264 site, so
`LIBVA_DRIVER_NAME=iHD` is set in `hyprland.lua`.

Brave reads `~/.config/brave-flags.conf` — **not** `chromium-flags.conf`.

### Screen sharing needs an explicit backend

`gnome.portal` also claims `ScreenCast`, and GNOME is installed as the fallback
session. Without `xdg-desktop-portal/hyprland-portals.conf` pinning the
hyprland backend, screen sharing silently routes to GNOME's and fails.

---

## Layout

```
.config/hypr/          hyprland.lua, hyprlock, hypridle, hyprpaper, scripts/
.config/waybar/        config.jsonc, style.css, scripts/
.config/rofi/          launcher + power menu themes and script
.config/swaync/        notification centre config and CSS
.config/kitty/         terminal
.config/fastfetch/     greeter + spider ASCII logo
.config/xdg-desktop-portal/
Pictures/Wallpapers/   wallpapers, avatar
.bashrc                greeter guard, yazi `y` wrapper
```
