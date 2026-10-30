{
  inputs.nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";

  outputs = inputs:
    let
      forPkgs = pkgs:
        let
          name = "git-remote-gs";
          mock_blobcp = pkgs.writeShellScriptBin
            "blobcp"
            (builtins.readFile ./mock_blobcp);
          package = pkgs.writeShellApplication {
            name = name;
            runtimeInputs = [
              pkgs.git
              pkgs.jq
            ];
            text = builtins.readFile ./${name};
          };
          check = pkgs.runCommand "bats-test" {
            nativeBuildInputs = [
              package
              mock_blobcp
              pkgs.git
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
