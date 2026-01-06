{ pkgs, lib, config, inputs, ... }: {
  languages = {
    dart.enable = true;
    rust = {
      enable = true;
      channel = "stable";
      targets = [ "wasm32-unknown-unknown" ];
    };
    kotlin.enable = true;
  };

  packages = with pkgs; [ rustup libappindicator kotlin-language-server xdg-user-dirs pkg-config ];

  # Configure adnroid development
  # https://devenv.sh/integrations/android/
  android = {
    enable = true;
    platforms.version = [ "33" "34" "35" "36" ];
    flutter.enable = true;
  };

  enterShell = ''
    export LD_LIBRARY_PATH="$(pwd)/build/linux/x64/debug/bundle/lib:$(pwd)/build/linux/x64/release/bundle/lib:$LD_LIBRARY_PATH"
  '';
}

