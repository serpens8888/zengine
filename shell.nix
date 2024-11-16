{ pkgs ? import <nixpkgs> {} }:

let
    unstable = import <nixos-unstable> {};
in
    pkgs.mkShell{
	    
	buildInputs = [
	    unstable.zig

	    #pkgs.SDL3 #wait for it to be packaged

	    pkgs.miniaudio

	    pkgs.pkg-config

	    pkgs.vulkan-headers
	    pkgs.vulkan-loader
	    pkgs.vulkan-validation-layers
	    unstable.vulkan-memory-allocator

	    

	];





}
