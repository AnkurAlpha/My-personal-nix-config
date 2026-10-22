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
    smoothcursor = {
        url = "git+https://github.com/gen740/SmoothCursor.nvim?rev=12518b284e1e3f7c6c703b346815968e1620bee2";
        flake = false;
    };
    nvimEmmet = {
      url = "git+https://github.com/olrtg/nvim-emmet";
      flake = false;
    };
    vimReactSnippets = {
      url = "git+https://github.com/mlaursen/vim-react-snippets";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, nixvim, fimloom, smoothcursor, nvimEmmet, vimReactSnippets, ... }:
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
            home-manager.sharedModules = [ nixvim.homeModules.nixvim ./home/ankur/hyprland/nwg-bar.nix ];
            home-manager.extraSpecialArgs = {
                fimloomSrc = fimloom;
                smoothcursorSrc = smoothcursor;
                nvimEmmetSrc = nvimEmmet;
                vimReactSnippetsSrc = vimReactSnippets;
            };

            home-manager.users.ankur =
              import ./home/ankur/home.nix;
          }
        ];
      };
    in
    {
      # Flake-pinned isolated dev shells; host services and GPU are unchanged.
      devShells.x86_64-linux = import ./modules/development/dev-shells.nix {
        inherit nixpkgs;
        settings = import ./hosts/ankur-laptop/dev-environments.nix;
      };

      nixosConfigurations = {
        ankur-laptop = ankurLaptop;

        # Temporary alias for the existing hostname
        nixos = ankurLaptop;
        # Independent minimal ISO: never imports the laptop hardware or Home Manager.
        ankur-installer-iso = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./hosts/installer-iso/default.nix ];
        };
      };
    };
}
