{
  inputs.nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";

  outputs = inputs:
    let
      forPkgs = pkgs:
        let
          package = pkgs.writeShellApplication {
            name = "app";
            text = builtins.readFile ./app.sh;
          };
          check = pkgs.runCommand "bats-test" {
            nativeBuildInputs = [
              (pkgs.bats.withLibraries (p: [
                p.bats-support
                p.bats-assert
              ]))
            ];
          } ''
            ln -s ${package}/bin/app ./app.sh
            bats ${./test.bats}
            touch $out
          '';
        in
        { inherit package check; };

      allSystems = builtins.mapAttrs
        (system: forPkgs)
        inputs.nixpkgs.legacyPackages;

      forAllSystems = key:
        builtins.mapAttrs
          (system: sys: { default = sys.${key}; })
          allSystems;
    in
    {
      packages = forAllSystems "package";
      checks = forAllSystems "check";
    };
}
