{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";

    gfngfn-camlpdf = {
      url = "github:gfngfn/camlpdf/3a3c34a71aed90ad12f3d0ffcc695b0860222f3e";
      flake = false;
    };
    gfngfn-otfm = {
      url = "github:gfngfn/otfm/0ec52b8d2e4040c752ba42a9c8ac2375c4909149";
      flake = false;
    };
    gfngfn-yojson-with-position = {
      url = "github:gfngfn/yojson-with-position/b0a5df4dea2205266285ea5105b3a3883fac9d3e";
      flake = false;
    };

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };
  outputs = {
    self,
    nixpkgs,
    flake-utils,
    devshell,
    gfngfn-camlpdf,
    gfngfn-otfm,
    gfngfn-yojson-with-position,
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            devshell.overlay
            (final: prev: {
              ocamlPackages =
                prev.ocamlPackages
                // {
                  camlpdf = with prev;
                    ocamlPackages.camlpdf.overrideAttrs (o: {
                      src = fetchFromGitHub {
                        owner = "gfngfn";
                        repo = "camlpdf";
                        rev = gfngfn-camlpdf.rev;
                        sha256 = gfngfn-camlpdf.narHash;
                      };
                    });
                  otfm = with prev;
                    ocamlPackages.otfm.overrideAttrs (o: {
                      src = fetchFromGitHub {
                        owner = "gfngfn";
                        repo = "otfm";
                        rev = gfngfn-otfm.rev;
                        sha256 = gfngfn-otfm.narHash;
                      };
                    });
                  yojson-with-position = with prev;
                    ocamlPackages.buildDunePackage {
                      pname = "yojson-with-position";
                      version = gfngfn-yojson-with-position.rev;
                      src = fetchFromGitHub {
                        owner = "gfngfn";
                        repo = "yojson-with-position";
                        rev = gfngfn-yojson-with-position.rev;
                        sha256 = gfngfn-yojson-with-position.narHash;
                      };
                      useDune2 = true;
                      nativeBuildInputs = [ocamlPackages.cppo];
                      propagatedBuildInputs = [ocamlPackages.biniou];
                      inherit (ocamlPackages.yojson) meta;
                    };
                };
            })
          ];
        };
      in rec {
        packages = with pkgs; {
          satysfi = ocamlPackages.buildDunePackage {
            pname = "satysfi";
            version = "0.0.7";

            src = self;
            nativeBuildInputs = [
              dune_2
            ];
            buildInputs = with ocamlPackages; [
              batteries
              camlimages
              camlpdf
              core_kernel
              cppo
              findlib
              menhir
              menhirLib
              ocaml
              omd
              otfm
              ppx_deriving
              re
              uutf
              yojson-with-position
            ];
          };
        };
        defaultPackage = packages.satysfi;

        devShell = pkgs.devshell.mkShell {
          imports = [
            (pkgs.devshell.importTOML ./devshell.toml)
          ];
        };
      }
    );
}
