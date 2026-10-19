
{
  description = "Ankur's multi-host NixOS configuration";

  inputs = {
    nixpkgs.url =
      "github:NixOS/nixpkgs?rev=7fc6f2c20af09cdcaf48b92ec3121860139ec668";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      ankurLaptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./hosts/ankur-laptop/configuration.nix

          home-manager.nixosModules.home-manager

          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

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

# {
#   description = "Ankur's NixOS configuration";
# 
#   inputs = {
#     nixpkgs.url =
#       "github:NixOS/nixpkgs?rev=7fc6f2c20af09cdcaf48b92ec3121860139ec668";
# 
#     home-manager = {
#       url = "github:nix-community/home-manager/release-26.05";
#       inputs.nixpkgs.follows = "nixpkgs";
#     };
#   };
# 
#   outputs = { self, nixpkgs, home-manager, ... }: {
#     nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
#       system = "x86_64-linux";
# 
#       modules = [
#         ./configuration.nix
# 
#         home-manager.nixosModules.home-manager
# 
#         {
#           home-manager.useGlobalPkgs = true;
#           home-manager.useUserPackages = true;
# 
#           home-manager.users.ankur =
#             import ./home/ankur/home.nix;
#         }
#       ];
#     };
#   };
# }
