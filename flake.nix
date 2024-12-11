{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs { inherit system; };

          name = "tr33_control";

          src = pkgs.lib.cleanSource ./.;

          buildInputs = with pkgs;[ coreutils gnumake git nodejs beam.packages.erlangR26.elixir_1_15 ];
        in
        {
          # packages.mix_release = beamPackages.mixRelease {
          #   inherit version pname elixir src;

          #   mixNixDeps = with pkgs; import ./mix_deps.nix { inherit lib beamPackages; };

          #   # For quicker releases
          #   # stripDebug = false;
          # };

          devShell = pkgs.mkShell
            {
              inherit name buildInputs;
            };
        });
}




