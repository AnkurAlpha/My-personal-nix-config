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
    # Pin NeoMinimap independently; the lockfile records an immutable revision.
    neominimap = {
      url = "github:Isrothy/neominimap.nvim/v3.16.0";
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

  outputs = { self, nixpkgs, home-manager, nixvim, fimloom, smoothcursor, nvimEmmet, vimReactSnippets, neominimap, ... }:
    let
      # New hosts are opt-in directories with their own hardware configuration.
      # Keep the original laptop and installer definitions independent.
      installerIsos = import ./lib/isos.nix { inherit nixpkgs; source = self.outPath; };
      additionalHosts = import ./lib/hosts.nix { inherit nixpkgs home-manager; };
      ankurLaptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./hosts/nixos/configuration.nix

          home-manager.nixosModules.home-manager

          ({ config, ... }: {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            # Nixvim extends Home Manager with programs.nixvim.
            home-manager.sharedModules = [ nixvim.homeModules.nixvim ./home/ankur/hyprland/nwg-bar.nix ];
            home-manager.extraSpecialArgs = {
                fimloomSrc = fimloom;
                smoothcursorSrc = smoothcursor;
                neominimapSrc = neominimap;
                nvimEmmetSrc = nvimEmmet;
                vimReactSnippetsSrc = vimReactSnippets;
            };

            home-manager.users.${config.my.user.name} =
              import ./home/ankur/home.nix;
          })
        ];
      };
    in
    {
      checks.x86_64-linux.username-flow = import ./tests/username-flow.nix {
        inherit nixpkgs; laptop = ankurLaptop;
      };
      checks.x86_64-linux.iso-accounts = import ./tests/isos.nix {
        inherit nixpkgs; source = self.outPath;
      };
      checks.x86_64-linux.portability = import ./tests/portability.nix {
        inherit nixpkgs home-manager;
      };

      # Flake-pinned isolated dev shells; host services and GPU are unchanged.
      devShells.x86_64-linux = import ./modules/development/dev-shells.nix {
        inherit nixpkgs;
        settings = import ./hosts/nixos/dev-environments.nix;
      };

      # Standalone Home Manager for Garuda Linux.
      # Does not modify NixOS, pacman, GRUB or system services.
      homeConfigurations = {
        "ankur@garuda" = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };

          modules = [
            ./hosts/garuda/home.nix
            { my.user.name = "ankur"; }
          ];
        };
      };

      nixosConfigurations = assert nixpkgs.lib.intersectLists
        (builtins.attrNames additionalHosts) (builtins.attrNames installerIsos) == [];
        additionalHosts // installerIsos // {
        nixos = ankurLaptop;

        # Independent minimal ISO: never imports the laptop hardware or Home Manager.
        # Compatibility alias; public workflows use iso-minimal / iso-hyprland.
        ankur-installer-iso = installerIsos.iso-minimal;
      };
    };
}
