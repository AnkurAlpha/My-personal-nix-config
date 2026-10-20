{
  description = "Ankur's multi-host NixOS configuration";

  inputs = {
    nixpkgs.url =
      "github:NixOS/nixpkgs?rev=7fc6f2c20af09cdcaf48b92ec3121860139ec668";

    # Nixvim is matched to the NixOS 26.05 release.
    nixvim.url = "git+https://github.com/nix-community/nixvim?ref=nixos-26.05";

    # The repository itself is pinned in flake.lock (no mutable local checkout).
    fimloom = {
      url = "git+https://github.com/AnkurAlpha/fimloom.nvim";
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixvim, fimloom, ... }:
    let
      ankurLaptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./hosts/ankur-laptop/configuration.nix

          home-manager.nixosModules.home-manager

          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            # Nixvim extends Home Manager with programs.nixvim.
            home-manager.sharedModules = [ nixvim.homeModules.nixvim ];
            home-manager.extraSpecialArgs = { fimloomSrc = fimloom; };

            home-manager.users.ankur =
              import ./home/ankur/home.nix;
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        ankur-laptop = ankurLaptop;

        # Temporary alias for the existing hostname
        nixos = ankurLaptop;
      };
    };
}
