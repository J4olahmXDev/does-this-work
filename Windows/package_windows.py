"""Build the portable Windows x64 v0.6 ZIP with the official Electron runtime."""
import argparse
import hashlib
from pathlib import Path, PurePosixPath
import shutil
from tempfile import TemporaryDirectory
from zipfile import ZIP_DEFLATED, ZipFile

EXPECTED_HASH = "2ba6223afa9121f42831fefe92c434334907540165294fc56697449d12e7cfe9"
PROJECT = Path(__file__).resolve().parent
RELEASE_FOLDER = "Does This Work"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runtime", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    with args.runtime.open("rb") as stream:
        if hashlib.file_digest(stream, "sha256").hexdigest() != EXPECTED_HASH:
            parser.error("Expected the official Electron v45.4.1 Windows x64 ZIP.")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=args.output.parent) as temp:
        release = Path(temp) / RELEASE_FOLDER
        with ZipFile(args.runtime) as runtime:
            runtime.extractall(release)
        (release / "electron.exe").rename(release / "Does This Work.exe")
        (release / "resources/default_app.asar").unlink(missing_ok=True)
        shutil.copytree(PROJECT / "app", release / "resources/app")
        shutil.copyfile(PROJECT / "README.md", release / "Read me.md")
        archive = Path(temp) / "release.zip"
        with ZipFile(archive, "w", compression=ZIP_DEFLATED, compresslevel=3) as output:
            for path in sorted(release.rglob("*")):
                if path.is_file():
                    name = PurePosixPath(RELEASE_FOLDER) / path.relative_to(release).as_posix()
                    output.write(path, name)
        archive.replace(args.output)


if __name__ == "__main__":
    main()
