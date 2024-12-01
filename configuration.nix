{ pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ];

  system.stateVersion = "24.11";

  networking.hostName = "unpersist";

  # Only manage users via NixOS
  users.mutableUsers = false;

  # Disable root account
  users.users.root.hashedPassword = "!";

  # Create a single user
  users.users.user = {
    isNormalUser = true;
    extraGroups = [
      # allow sudo usage
      "wheel"
    ];
    hashedPasswordFile = "/nix/persist/user.pass";
  };

  # Install few basic tools
  environment.systemPackages = with pkgs; [ vim firefox ];

  networking.networkmanager.enable = true;

  # Persistent files
  environment.etc."machine-id".source = "/nix/persist/etc/machine-id";
  environment.etc."NetworkManager/system-connections".source =
    "/nix/persist/etc/NetworkManager/system-connections";
}
