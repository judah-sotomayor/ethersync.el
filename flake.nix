{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    ethersync.url = "github:ethersync/ethersync";
  };

  outputs = {self, ethersync, nixpkgs} :
    let
      forAllSystems = function:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-darwin"
        ] (system: function nixpkgs.legacyPackages.${system} system);
    in
      {
        devShells = forAllSystems (pkgs: system: {
          default = pkgs.mkShell {
            packages = with pkgs; [
              emacs
              ethersync.packages.${system}.default
            ];
          };

          qualityChecks = pkgs.mkShell {
            name = "quality";
            packages = with pkgs; [
              cocogitto
            ];
          };
        });
      };
}
