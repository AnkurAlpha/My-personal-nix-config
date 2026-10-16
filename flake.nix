{
  description = "Ankur's NixOS configuration";

  inputs = {
    nixpkgs.url =
      "github:NixOS/nixpkgs?rev=7fc6f2c20af09cdcaf48b92ec3121860139ec668";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        ./configuration.nix
      ];
    };
  };
}
