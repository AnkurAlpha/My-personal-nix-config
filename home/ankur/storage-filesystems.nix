{ osConfig, lib, ... }:
let
  storage = osConfig.my.system.storageFilesystems;
in
{
  # No services are installed or started until BOTH switches are enabled.
  services.udiskie.enable = lib.mkIf (storage.enable && storage.removable.udiskieAutomount.enable) true;
}
