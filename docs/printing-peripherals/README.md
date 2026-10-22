# Printing & Peripherals (all new features disabled)

- Host switches: `hosts/ankur-laptop/printing-peripherals.nix`
- Options and implementation: `modules/system/printing-peripherals.nix`
- **Important:** `hosts/ankur-laptop/configuration.nix` already enables CUPS. The
  disabled `printing.cups.enable` flag does **not** disable that existing setting.
- All newly introduced features are disabled until `my.system.printingPeripherals.enable`
  and the specific feature flag are both set to `true`.
- Nothing modifies NetworkManager, existing USB permissions, Home Manager,
  `/mnt/garuda`, or the current filesystem mounts.

## Examples

To install a printer settings GUI while keeping existing CUPS:

```nix
my.system.printingPeripherals.enable = true;
my.system.printingPeripherals.printing.gui.enable = true;
```

To enable scanning with a network scanner:

```nix
my.system.printingPeripherals.enable = true;
my.system.printingPeripherals.scanning.airscan.enable = true;
my.system.printingPeripherals.scanning.gui.enable = true;
```

To enable Android debugging:

```nix
my.system.printingPeripherals.enable = true;
my.system.printingPeripherals.mobile.adb.enable = true;
```

ADB may also require membership in an `adbusers` group and a new login session.
Do not connect untrusted devices for debugging. Network printer discovery and
Thunderbolt authorization should only be enabled when needed.

After changing switches, build then switch:

```bash
nh os build ~/nixos-config -H ankur-laptop
nh os switch ~/nixos-config -H ankur-laptop
```

Neither this installer nor the module installs printer drivers for a specific
make/model. Add a driver only when you know the printer requirements.
