{ pkgs, ... }:

{
  home.packages = [ pkgs.trash-cli ];

  systemd.user.services.trash-cleanup = {
    Unit.Description = "Delete trashed files older than 30 days";

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.trash-cli}/bin/trash-empty 30";
    };
  };

  systemd.user.timers.trash-cleanup = {
    Unit.Description = "Daily Trash cleanup";

    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };

    Install.WantedBy = [ "timers.target" ];
  };
}
