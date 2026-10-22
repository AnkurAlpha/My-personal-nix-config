{ ... }: {
  # Nothing updates on a schedule: run nix-update-safe manually when desired.
  my.system.nixosUpdates = {
    enable = true;
    repoPath = "/home/ankur/nixos-config";
    host = "ankur-laptop";
    cli.enable = true;
    diagnostics.enable = true;
    updates.safeAll.enable = true;             # safe set: Home Manager / Nixvim / editing inputs
    updates.allInputs.enable = false;          # potentially updates FIMLoom: off
    updates.allowFimloom.enable = false;       # preserve FIMLoom exactly
    updates.allowNixpkgsPinChange.enable = false; # preserve pinned Nixpkgs revision
    validation.flakeCheck.enable = false;      # optional extra validation
    safety.confirmBeforeSwitch.enable = true;
    git.autoCommit.enable = true;              # commit only after successful switch
  };
}
