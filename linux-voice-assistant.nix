{
  lib,
  python3Packages,
  fetchFromGitHub,
  fetchPypi,
}:

let
  # aioesphomeapi 37.2.1 as required by linux-voice-assistant v1.0.0
  # (nixpkgs has 42.x which has breaking API changes)
  aioesphomeapi = python3Packages.buildPythonPackage rec {
    pname = "aioesphomeapi";
    version = "37.2.1";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-aJfMcWoqGnsWAJaU9gWd11IBsq5sltYk4jJBScY7GTU=";
    };

    build-system = [
      python3Packages.setuptools
      python3Packages.cython
    ];

    dependencies = [
      python3Packages.aiohappyeyeballs
      python3Packages.async-interrupt
      python3Packages.protobuf
      python3Packages.zeroconf
      python3Packages.chacha20poly1305-reuseable
      python3Packages.cryptography
      python3Packages.noiseprotocol
    ];

    # Tests require network
    doCheck = false;

    pythonImportsCheck = [ "aioesphomeapi" ];

    meta = {
      description = "Python API for interacting with ESPHome devices";
      homepage = "https://github.com/esphome/aioesphomeapi";
      license = lib.licenses.mit;
    };
  };

  # pymicro-features v1.0.0 as required by linux-voice-assistant v1.0.0
  pymicro-features = python3Packages.buildPythonPackage rec {
    pname = "pymicro-features";
    version = "1.0.0";
    pyproject = true;

    src = fetchPypi {
      pname = "pymicro_features";
      inherit version;
      hash = "sha256-odKKfWaHvI11ydYnLJJl2CZvFQlO3NnsjShGGWj290Y=";
    };

    build-system = [
      python3Packages.setuptools
      python3Packages.pybind11
    ];

    dependencies = [ python3Packages.numpy ];

    pythonImportsCheck = [ "pymicro_features" ];

    meta = {
      description = "Audio feature extraction for wake word detection";
      homepage = "https://github.com/rhasspy/pymicro-features";
      license = lib.licenses.asl20;
    };
  };

in
python3Packages.buildPythonPackage rec {
  pname = "linux-voice-assistant";
  version = "1.0.0";
  pyproject = true;

  disabled = python3Packages.pythonOlder "3.9";

  src = fetchFromGitHub {
    owner = "OHF-Voice";
    repo = "linux-voice-assistant";
    tag = "v${version}";
    hash = "sha256-dPmoimohvTR+DPUIN4LenkWwxNvHGM0Hi8Q5XgFUsq8=";
  };

  build-system = [ python3Packages.setuptools ];

  # Fix typo and relax version constraints for nixpkgs compatibility
  # Add console script entry point
  # Fix data directory paths
  postPatch = ''
    sed -i 's/python-mpv=>1/mpv>=1/g' pyproject.toml
    sed -i 's/pymicro-features==1.0.0/pymicro_features/g' pyproject.toml
    sed -i 's/aioesphomeapi==37.2.1/aioesphomeapi/g' pyproject.toml

    # Fix data directory paths to use installed location for read-only data
    # and XDG directories for writable data
    substituteInPlace linux_voice_assistant/__main__.py \
      --replace-fail '_REPO_DIR = _MODULE_DIR.parent' '_REPO_DIR = Path("@out@/share/linux-voice-assistant")'

    # Add sync wrapper for console script
    cat >> linux_voice_assistant/__main__.py << 'EOF'

def _cli():
    """Sync entry point for console script."""
    asyncio.run(main())
EOF

    # Add console script entry point
    cat >> pyproject.toml << 'EOF'

[project.scripts]
linux-voice-assistant = "linux_voice_assistant.__main__:_cli"
EOF
  '';

  postInstall = ''
    # Install data files
    mkdir -p $out/share/linux-voice-assistant
    cp -r wakewords $out/share/linux-voice-assistant/
    cp -r sounds $out/share/linux-voice-assistant/
    cp -r lib $out/share/linux-voice-assistant/

    # Substitute the actual output path
    substituteInPlace $out/lib/python*/site-packages/linux_voice_assistant/__main__.py \
      --replace-fail '@out@' "$out"
  '';

  dependencies = [
    aioesphomeapi
    python3Packages.sounddevice
    python3Packages.numpy
    python3Packages.mpv
    pymicro-features
  ];

  # Tests require network access
  doCheck = false;

  pythonImportsCheck = [ "linux_voice_assistant" ];

  meta = {
    changelog = "https://github.com/OHF-Voice/linux-voice-assistant/releases/tag/v${version}";
    description = "Linux voice assistant for Home Assistant using the ESPHome protocol";
    homepage = "https://github.com/OHF-Voice/linux-voice-assistant";
    license = lib.licenses.asl20;
    mainProgram = "linux-voice-assistant";
  };
}
