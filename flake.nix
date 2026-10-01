{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  outputs = inputs: {
    packages =
      inputs.nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ] (system: rec {
        default = qemu-win10;
        qemu-win10 = inputs.nixpkgs.legacyPackages.${system}.callPackage ./. {};
      });
  };
}
