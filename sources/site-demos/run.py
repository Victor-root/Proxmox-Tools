"""Records the demos of the site and writes them to site/demos/.

python3 run.py                 every recording of record/
python3 run.py modern-theme    only the ones named
"""
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

import assemble
import prepare

HERE = Path(__file__).resolve().parent
PORT = 8010


def main(names):
    names = names or sorted(p.stem for p in (HERE / "record").glob("*.js"))
    prepare.main()
    server = subprocess.Popen([sys.executable, str(HERE / "server.py"), str(PORT)])
    try:
        for _ in range(50):
            with socket.socket() as s:
                if s.connect_ex(("127.0.0.1", PORT)) == 0:
                    break
            time.sleep(0.1)
        for name in names:
            subprocess.run(["node", str(HERE / "record" / f"{name}.js")], check=True,
                           env={**os.environ, "DEMO_PORT": str(PORT)})
            assemble.build(name, HERE.parent.parent / "site/demos" / f"{name}.webp")
    finally:
        server.terminate()


if __name__ == "__main__":
    main(sys.argv[1:])
