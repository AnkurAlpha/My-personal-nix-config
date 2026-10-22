{ ... }: {
  # Set enable = false to disable this whole cleanup policy.
  # Setting plasma.disable = false allows the host's previous Plasma setting.
  my.system.kdeCleanup = {
    enable = true;
    plasma.disable = true;            # Remove Plasma session and its auto-installed stack
    kwallet.disablePam = true;        # No PAM KWallet autounlock
    kwallet.disableForUser = false;    # Home Manager writes ~/.config/kwalletrc
  };
}
