{
  inputs.nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";

  outputs = inputs:
    let
      forPkgs = pkgs:
        let
          name = "git-remote-gs";
          package = pkgs.writeShellApplication {
            name = name;
            text = builtins.readFile ./${name};
          };
          check = pkgs.runCommand "bats-test" {
            nativeBuildInputs = [
              package
              pkgs.git
              pkgs.jq
              (pkgs.bats.withLibraries (p: [
                p.bats-support
                p.bats-assert
              ]))
            ];
          } ''
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
