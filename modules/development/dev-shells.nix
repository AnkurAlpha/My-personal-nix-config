{ nixpkgs, settings }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  lib = pkgs.lib;
  base = with pkgs; [ git gnumake cmake pkg-config ];
  enabled = name: (builtins.getAttr name settings).enable or false;
  shell = name: packages: pkgs.mkShell {
    name = "ankur-${name}";
    inherit packages;
  };
in
  lib.optionalAttrs (settings.enable or false) (
    { default = shell "default" base; }
    // lib.optionalAttrs (enabled "cpp") {
      cpp = shell "cpp" (base ++ (with pkgs; [ gcc gdb ninja ]));
    }
    // lib.optionalAttrs (enabled "python") {
      python = shell "python" (with pkgs; [ python3 uv ruff ]);
    }
    // lib.optionalAttrs (enabled "rust") {
      rust = shell "rust" (with pkgs; [ rustc cargo rustfmt clippy ]);
    }
    // lib.optionalAttrs (enabled "node") {
      node = shell "node" (with pkgs; [ nodejs pnpm ]);
    }
    // lib.optionalAttrs (enabled "java") {
      java = shell "java" (with pkgs; [ jdk21 maven ]);
    }
    // lib.optionalAttrs (enabled "clang") {
      clang = shell "clang" (base ++ (with pkgs; [ clang clang-tools lldb ]));
    }
    // lib.optionalAttrs (enabled "go") {
      go = shell "go" (with pkgs; [ go gopls ]);
    }
    // lib.optionalAttrs (enabled "fullstack") {
      fullstack = shell "fullstack" (with pkgs; [ nodejs pnpm python3 uv ]);
    }
  )
