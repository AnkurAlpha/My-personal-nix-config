{ config, ... }: {
  # Nothing updates on a schedule: run nix-update-safe manually when desired.
  my.system.nixosUpdates = {
    enable = true;
    repoPath = "${config.my.user.homeDirectory}/nixos-config";
    host = "nixos";
    cli.enable = true;
    diagnostics.enable = true;
    updates.safeAll.enable = true;             # safe set: Home Manager / Nixvim / editing inputs
    updates.allInputs.enable = false;          # potentially updates FIMLoom: off
    updates.allowFimloom.enable = false;       # prepare requires an explicit FIMLoom opt-in
    updates.allowNixpkgsPinChange.enable = false; # reserve explicit SHA overrides
    validation.flakeCheck.enable = false;      # prepare and validate always run checks
    safety.confirmBeforeSwitch.enable = true;
    git.autoCommit.enable = true;              # commit only after successful switch
  };
}
