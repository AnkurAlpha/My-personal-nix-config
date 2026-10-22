{ lib, osConfig, ... }: {
  # KDE applications (e.g. Dolphin, Okular) may still pull in KDE libraries.
  # This disables the wallet subsystem rather than deleting stored credentials.
  xdg.configFile."kwalletrc" = lib.mkIf
    (osConfig.my.system.kdeCleanup.enable && osConfig.my.system.kdeCleanup.kwallet.disableForUser) {
      text = ''
        [Wallet]
        Enabled=false
        [KSecretD]
        Enabled=false
      '';
    };
}
