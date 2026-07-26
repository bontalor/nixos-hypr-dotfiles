{
    description = "lor nixos hyprland pywal";

    inputs = {
	nixpkgs.url = "nixpkgs/nixos-unstable";
	home-manager = {
	    url = "github:nix-community/home-manager";
	    inputs.nixpkgs.follows = "nixpkgs";
	};
	mcsr-nixos = {
	    url = "https://git.uku3lig.net/uku/mcsr-nixos/archive/main.tar.gz";
	    inputs.nixpkgs.follows = "nixpkgs";
	};
    };
    outputs = { nixpkgs, home-manager, mcsr-nixos, ... }@inputs: {
	nixosConfigurations.lor-nixos = nixpkgs.lib.nixosSystem {
	    system = "x86_64-linux";
	    specialArgs = { inherit inputs; };
	    modules = [
		./configuration.nix
		    home-manager.nixosModules.home-manager
		    {
			home-manager = {
			    useGlobalPkgs = true;
			    useUserPackages = true;
			    users.bonta = import ./home.nix;
			    backupFileExtension = "backup";
			    extraSpecialArgs = { inherit inputs; };
			};
		    }
	    ];
	};
    };
}
