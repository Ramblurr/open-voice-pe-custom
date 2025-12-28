{
  lib,
  python3Packages,
  fetchFromGitHub,
  fetchPypi,
}:

let
  # pymicro-features v2.0.2 as required by pymicro-wakeword
  pymicro-features = python3Packages.buildPythonPackage rec {
    pname = "pymicro-features";
    version = "2.0.2";
    pyproject = true;

    src = fetchPypi {
      pname = "pymicro_features";
      inherit version;
      hash = "sha256-DQvteEPseLbO2C0aLc3etP5d9hs6+AooHQhoyOJ5xyc=";
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

  # pymicro-wakeword v2.1.0
  pymicro-wakeword = python3Packages.buildPythonPackage rec {
    pname = "pymicro-wakeword";
    version = "2.1.0";
    pyproject = true;

    src = fetchPypi {
      pname = "pymicro_wakeword";
      inherit version;
      hash = "sha256-MRRK+JJXw3zTkj3M+BTGd0qts3s89aVI+0Zs1q4kfcQ=";
    };

    build-system = [ python3Packages.setuptools ];

    dependencies = [
      python3Packages.numpy
      pymicro-features
    ];

    pythonImportsCheck = [ "pymicro_wakeword" ];

    meta = {
      description = "Lightweight wake word detection using TensorFlow Lite";
      homepage = "https://github.com/rhasspy/pymicro-wakeword";
      license = lib.licenses.asl20;
    };
  };

in
python3Packages.buildPythonPackage rec {
  pname = "linux-voice-assistant";
  version = "unstable-2025-12-28";
  pyproject = true;

  disabled = python3Packages.pythonOlder "3.9";

  src = fetchFromGitHub {
    owner = "OHF-Voice";
    repo = "linux-voice-assistant";
    rev = "main";
    hash = "sha256-/CKkbx0eYugj20GaRpOx8Xkugi96gSV8w5NvV1Zq9c4=";
  };

  build-system = [ python3Packages.setuptools ];

  # Relax version constraints for nixpkgs compatibility
  # Add console script entry point
  # Fix data directory paths
  postPatch = ''
    sed -i 's/aioesphomeapi==42.7.0/aioesphomeapi/g' pyproject.toml
    sed -i 's/pymicro-wakeword>=2,<3/pymicro_wakeword/g' pyproject.toml
    sed -i 's/pyopen-wakeword>=1,<2/pyopen_wakeword/g' pyproject.toml
    sed -i 's/python-mpv>=1,<2/mpv/g' pyproject.toml
    sed -i 's/soundcard<1/soundcard/g' pyproject.toml
    sed -i 's/zeroconf<1/zeroconf/g' pyproject.toml

    # Fix data directory paths to use installed location for read-only data
    # and XDG directories for writable data
    substituteInPlace linux_voice_assistant/__main__.py \
      --replace-fail '_REPO_DIR = _MODULE_DIR.parent' '_REPO_DIR = Path("@out@/share/linux-voice-assistant")' \
      --replace-fail 'default=_REPO_DIR / "local"' 'default=Path.home() / ".local/share/linux-voice-assistant"' \
      --replace-fail 'default=_REPO_DIR / "preferences.json"' 'default=Path.home() / ".local/share/linux-voice-assistant/preferences.json"'

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

    # Substitute the actual output path
    substituteInPlace $out/lib/python*/site-packages/linux_voice_assistant/__main__.py \
      --replace-fail '@out@' "$out"
  '';

  dependencies = [
    python3Packages.aioesphomeapi
    python3Packages.soundcard
    python3Packages.numpy
    python3Packages.zeroconf
    python3Packages.pyopen-wakeword
    python3Packages.mpv
    pymicro-wakeword
  ];

  # Tests require network access
  doCheck = false;

  pythonImportsCheck = [ "linux_voice_assistant" ];

  meta = {
    changelog = "https://github.com/OHF-Voice/linux-voice-assistant/commits/main";
    description = "Linux voice assistant for Home Assistant using the ESPHome protocol";
    homepage = "https://github.com/OHF-Voice/linux-voice-assistant";
    license = lib.licenses.asl20;
    mainProgram = "linux-voice-assistant";
  };
}
