{ osConfig, lib, ... }:
let
  storage = osConfig.my.system.storageFilesystems;
  declaredDevices = map (fs: fs.device or null) (builtins.attrValues osConfig.fileSystems);
  declaredUuids = lib.unique (map (lib.removePrefix "/dev/disk/by-uuid/")
    (lib.filter (device: builtins.isString device && lib.hasPrefix "/dev/disk/by-uuid/" device) declaredDevices));
in
{
  services.udiskie = lib.mkIf (storage.enable && storage.removable.udiskieAutomount.enable) {
    enable = true;
    automount = true;
    notify = true;
    # The Hyprland bar is launched separately; mounting must not wait for tray.target.
    tray = "never";
    settings.device_config = map (uuid: { id_uuid = uuid; ignore = true; }) declaredUuids;
  };
}
