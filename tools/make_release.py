#!/usr/bin/env python3
"""リリース物の組み立て (v1.9・P26・SPEC §37.8 / D91)。

使い方 (リポジトリルートで):
  python tools/make_release.py win <版>   # export/vansaba-like.exe から Windows リリース zip を作る
  python tools/make_release.py web        # export/html にライセンス同梱ファイルをコピーする

zip の中身 (§37.8):
  Vansaba Like!.exe / LICENSE / THIRD_PARTY_NOTICES.md /
  licenses/(GODOT_COPYRIGHT.txt, font/LICENSE.txt, font/OFL.txt, godot_mcp/LICENSE)
"""
from __future__ import annotations

import pathlib
import shutil
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
WIN_EXE = ROOT / "export/vansaba-like.exe"
WEB_DIR = ROOT / "export/html"
RELEASE_DIR = ROOT / "export/release"

# 同梱するライセンスファイル (リポジトリ内パス → 配布物内パス)
LICENSE_FILES = {
    "LICENSE": "LICENSE",
    "THIRD_PARTY_NOTICES.md": "THIRD_PARTY_NOTICES.md",
    "GODOT_COPYRIGHT.txt": "licenses/GODOT_COPYRIGHT.txt",
    "font/LICENSE.txt": "licenses/font/LICENSE.txt",
    "font/OFL.txt": "licenses/font/OFL.txt",
    "addons/godot_mcp/LICENSE": "licenses/godot_mcp/LICENSE",
}


def build_win(version: str) -> None:
    if not WIN_EXE.exists():
        sys.exit(f"error: {WIN_EXE} がありません (先に Windows 書き出しを実行)")
    out = RELEASE_DIR / f"VansabaLike_v{version}_win64.zip"
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(WIN_EXE, "Vansaba Like!.exe")
        for src, dst in LICENSE_FILES.items():
            z.write(ROOT / src, dst)
    print(f"wrote {out} ({out.stat().st_size / 1e6:.1f} MB)")
    with zipfile.ZipFile(out) as z:
        for name in z.namelist():
            print("  " + name)


def build_web() -> None:
    if not WEB_DIR.exists():
        sys.exit(f"error: {WEB_DIR} がありません (先に Web 書き出しを実行)")
    for src, dst in LICENSE_FILES.items():
        target = WEB_DIR / dst
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / src, target)
        print("copied " + dst)


def main() -> None:
    argv = sys.argv[1:]
    if len(argv) >= 2 and argv[0] == "win":
        build_win(argv[1])
    elif len(argv) == 1 and argv[0] == "web":
        build_web()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
