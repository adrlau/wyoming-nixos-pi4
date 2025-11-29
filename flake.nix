{
  description = "NixOS Pi4 with Wyoming + pinned kernel + Pi overlay";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    rpi-helper.url = "github:nvmd/nixos-raspberrypi/main";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rpi-helper, flake-utils, ... }:
  let
    system = "aarch64-linux";
    pkgs = import nixpkgs { inherit system; };
    # Optional: you can use the vendor kernel from rpi-helper instead; keeping your pin for now.
    kernel = pkgs.linuxPackages_6_1;
  in {
    nixosConfigurations.rpi-wyoming = rpi-helper.lib.nixosSystem {
      inherit pkgs system;
      # Pass required specialArgs so rpi-helper asserts succeed
      specialArgs = {
        nixos-raspberrypi = rpi-helper;
        # (Include alternative spelling just in case future helpers expect it)
        nixos-raspberry-pi = rpi-helper;
      };
      modules = [
        # Base Raspberry Pi 4 hardware setup from helper
        rpi-helper.nixosModules.raspberry-pi-4.base

        # SD image generation module (provides system.build.sdImage)
        rpi-helper.nixosModules.sd-image

        ({ config, pkgs, lib, ... }: {
          # Pin kernel (remove if you prefer rpi-helper's provided kernel bundle)
          boot.kernelPackages = kernel;

          # Optional extra device tree tweaks (rpi-helper modules already handle most)
          hardware.deviceTree.enable = true;
          hardware.deviceTree.filter = "bcm2711-rpi-*.dtb";
          hardware.raspberry-pi."4".i2c1.enable = true;

          users.users.pi = {
            isNormalUser = true;
            extraGroups = [ "audio" "video" ];
          };

            services.wyoming = {
              satellite = {
                enable = true;
                package = pkgs.wyoming-satellite;
                user = "pi";
                group = "audio";
                name = "pi-satellite";
                uri = "tcp://0.0.0.0:10700";
                extraArgs = "";
                vad.enable = false;
                microphone = {
                  autoGain = false;
                  noiseSuppression = 0;
                  command = "arecord -r 16000 -c 1 -f S16_LE -t raw";
                };
                sound = {
                  command = "aplay -r 22050 -c 1 -f S16_LE -t raw";
                  awake = "/home/pi/wyoming/sounds/awake.wav";
                  done  = "/home/pi/wyoming/sounds/done.wav";
                };
                area = "living-room";
              };

              piper = {
                package = pkgs.wyoming-piper;
                servers.default = {
                  enable = true;
                  uri    = "tcp://0.0.0.0:10200";
                  piper  = null;
                  voice  = "en_US-lessac-medium";
                  speaker = "default";
                  noiseWidth = 0.0;
                  noiseScale = 0.667;
                  lengthScale = 1.0;
                  extraArgs = "";
                };
              };

              "faster-whisper" = {
                package = pkgs.wyoming-faster-whisper;
                servers.default = {
                  enable = true;
                  uri   = "tcp://0.0.0.0:10300";
                  model = "tiny-int8";
                  language = "en";
                  initialPrompt = "";
                  device = "cpu";
                  beamSize = null;
                  extraArgs = "";
                };
              };

              openwakeword = {
                package = pkgs.wyoming-openwakeword;
                enable  = true;
                uri     = "tcp://0.0.0.0:10400";
                triggerLevel = null;
                threshold    = 0.5;
                preloadModels = [ "hey_rhasspy" ];
                customModelsDirectories = null;
                extraArgs = "";
              };
            };

          environment.systemPackages = with pkgs; [ ];
        })
      ];
    };
  };
}
