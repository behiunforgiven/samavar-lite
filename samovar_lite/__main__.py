import sys

try:
    from .app import main
except ImportError:
    from samovar_lite.app import main

if __name__ == "__main__":
    sys.exit(main())
