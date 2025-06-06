{
  description = "Patched version of Caddy";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let

      # to work with older version of flakes
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      version = builtins.substring 0 8 lastModifiedDate;

      # System types to support.
      supportedSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });

    in
    {

      # Provide some binary packages for selected system types.
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};

          caddy-unwrapped = pkgs.buildGoModule {
            pname = "caddy";
            inherit version;
            src = ./caddy-src;
            runVend = true;
            vendorHash = "sha256-/o7Zbiulb3YzknGyjjOPHZvv+AyA+TMhy+uujE+cBgE=";
            # vendorHash = pkgs.lib.fakeHash;

            meta = {
              homepage = "https://caddyserver.com";
              description = "Fast and extensible multi-platform HTTP/1-2-3 web server with automatic HTTPS";
              license = pkgs.lib.licenses.asl20;
              mainProgram = "caddy";
              maintainers = with pkgs.lib.maintainers; [
                Br1ght0ne
                emilylange
                techknowlogick
              ];
            };
          };

          # Wrap the caddy package to add the capability to bind to low ports.
          # Unfortunately this will not work in sandboxed environments because we use `setcap`.
          # Make sure to set `nix.settings.sandbox = false;` wherever you use this.
          caddy = pkgs.stdenv.mkDerivation {
            name = "caddy-with-cap";
            buildInputs = [ pkgs.libcap ];

            dontUnpack = true;

            installPhase = ''
              mkdir -p $out/bin
              cp ${caddy-unwrapped}/bin/caddy $out/bin/caddy
              setcap cap_net_bind_service=+ep $out/bin/caddy
            '';

            meta = caddy-unwrapped.meta // {
              description = "${caddy-unwrapped.meta.description} (with cap_net_bind_service)";
            };
          };
        in
        {
          inherit caddy-unwrapped caddy;
          default = caddy;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [ go ];
          };
        }
      );

    };
}
