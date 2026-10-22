# Dormant feature switches. Everything added by this module is OFF by default.
# Existing CUPS (declared in configuration.nix) remains enabled independently.
{ ... }:
{
  my.system.printingPeripherals = {
    enable = false;

    printing = {
      cups.enable = false;
      gui.enable = false;
      discovery.enable = false;
    };

    scanning = {
      sane.enable = false;
      airscan.enable = false;
      gui.enable = false;
    };

    mobile = {
      mtp.enable = false;
      adb.enable = false;
      ios.enable = false;
    };

    peripherals = {
      usbInspect.enable = false;
      thunderbolt.enable = false;
    };
  };
}
