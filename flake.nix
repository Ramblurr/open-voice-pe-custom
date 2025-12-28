{
  description = "dev env";
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # tracks nixpkgs unstable branch
    devshell.url = "github:numtide/devshell";
    devenv.url = "https://flakehub.com/f/ramblurr/nix-devenv/*";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    {
      self,
      devenv,
      devshell,
      ...
    }:
    devenv.lib.mkFlake ./. {
      withOverlays = [
        devshell.overlays.default
        devenv.overlays.default
      ];
      packages = {
        linux-voice-assistant = pkgs: (pkgs.callPackage ./linux-voice-assistant.nix { });
        linux-voice-assistant-unstable = pkgs: (pkgs.callPackage ./linux-voice-assistant-unstable.nix { });
      };
      devShell =
        pkgs:
        pkgs.devshell.mkShell {
          imports = [
            devenv.capsules.base
          ];
          # https://numtide.github.io/devshell
          commands = [
          ];
          packages = [
            pkgs.portaudio
            pkgs.mpv
            #pkgs.python313
            (pkgs.python313.withPackages (
              ps: with ps; [
                pip
                numpy
              ]
            ))

          ];

        };
    };
}
