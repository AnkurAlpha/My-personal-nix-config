{ ... }:

{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "AnkurAlpha";
        email = "comp2ankur@gmail.com";
      };

      safe.directory = "/etc/nixos";
    };
  };
}
