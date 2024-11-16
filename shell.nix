{ pkgs ? import <nixpkgs> {} }:

let
    unstable = import <nixos-unstable> {};

    sdl3 = pkgs.stdenv.mkDerivation {
	pname = "SDL3";
	version = "3.1.6";

	src = pkgs.fetchFromGitHub{
	    owner = "libsdl-org";
	    repo = "SDL";
	    rev = "78cc5c173404488d80751af226d1eaf67033bcc4";
	    sha256 = "sha256-MItZt5QeEz13BeCoLyXVUbk10ZHNyubq7dztjDq4nt4=";

	};

	nativeBuildInputs = [pkgs.cmake];

	buildInputs = [  
	    pkgs.wayland
	    pkgs.libdecor
	    pkgs.libxkbcommon
	    pkgs.egl-wayland
	    pkgs.xorg.libX11
	    pkgs.xorg.libXext
	    pkgs.xorg.libXrandr
	    pkgs.xorg.libXi
	    pkgs.xorg.libXcursor
	];

	meta = with pkgs.lib; {
	    description = "Simple DirectMedia Layer 3 for X and Wayland";
	    homepage = "https://github.com/libsdl-org/SDL";
	    license = licenses.zlib;

	};
    };
	
in
    pkgs.mkShell{
	    
	buildInputs = [
	    unstable.zig
	    sdl3
	    pkgs.pkg-config
	    pkgs.vulkan-headers
	    pkgs.vulkan-loader
	    pkgs.vulkan-validation-layers
	    unstable.vulkan-memory-allocator

	];

}
