{
  description = "NixOS Pi4 with Wyoming + pinned kernel + Pi overlay";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    rpi-helper.url = "github:nvmd/nixos-raspberrypi/main";
    # (Optionally pin a revision of rpi-helper if you want stability)
    # rpi-helper.rev = "...";
  };

  outputs = { self, nixpkgs, rpi-helper, ... }:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };

      # choose a fixed kernel version
      kernel = pkgs.linuxPackages_6_1;
    in {
      nixosConfigurations.rpi-wyoming = rpi-helper.lib.nixosSystem {
        inherit pkgs system;
        modules = [
          ({ config, pkgs, ... }: {
            # Pin kernel
            boot.kernelPackages = kernel;

            # Enable device-tree + overlays for Pi
            hardware.deviceTree.enable = true;
            hardware.deviceTree.filter = "bcm2711-rpi-*.dtb";
            hardware.raspberry-pi."4".i2c1.enable = true;
            # If you have I2S/I2C/other overlays, you can add more here.

            # Example: disable on-board audio if you prefer, might help avoid conflicts
            # boot.loader.raspberryPi.dtParams = {
            #   audio = "off";
            # };

            # User and audio groups
            users.users.pi = {
              isNormalUser = true;
              extraGroups = [ "audio" "video" ];
            };

            # WYOMING services (as previous)
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

            # systemPackages, extra config, etc.
            environment.systemPackages = with pkgs; [ ];
          })
        ];
      };
    };
}
