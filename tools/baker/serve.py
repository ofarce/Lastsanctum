#!/usr/bin/env python3
"""Serveur du baker : extrait les graphismes procéduraux du prototype JS.

Usage :
    python3 tools/baker/serve.py                # extraction complète de la version figée
    python3 tools/baker/serve.py --page reference.html --out tests/visual/reference
    python3 tools/baker/serve.py --rev WORKTREE # dossier de travail au lieu de la version figée
    python3 tools/baker/serve.py --no-browser   # ouvrir l'URL affichée à la main

Version figée (MIGRATION_PLAN.md v2, décision D10) : par défaut, les fichiers du prototype sont lus
dans l'historique git au commit REFERENCE_REV, par `git show <rev>:<chemin>`. Le dossier de travail
peut donc évoluer pendant la migration sans changer les extractions.

Garanties de sécurité (R23) :
- le prototype est lu en LECTURE SEULE (git show / cat-file, et status sans verrou optionnel) ;
- un instantané du dépôt (HEAD, références, état du dossier de travail, date de l'index) est
  comparé avant et après : toute différence fait échouer l'exécution ;
- les écritures (POST /out/<chemin>) sont confinées au dossier de sortie, sans traversée ;
- seules les extensions .png et .json sont acceptées en écriture.
"""
from __future__ import annotations

import argparse
import hashlib
import http.server
import json
import mimetypes
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path
from urllib.parse import unquote, urlparse

BAKER_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BAKER_DIR.parents[1]
DEFAULT_SRC = Path('/home/drums/code/exilesdefense')
# Version de référence de la migration (MIGRATION_PLAN.md v2). « WORKTREE » = dossier de travail.
# Décision D15 : 73b410f + charte graphique seule (branche charte-graphique du prototype).
REFERENCE_REV = '195114ec12daad6cd8ecc939ec350e99fe9ae175'
ALLOWED_OUT = {'.png', '.json'}
# Fichiers du prototype réutilisés tels quels (MIGRATION_PLAN.md §3.1).
IMPORTED = {'assets/portal-atlas.png': 'portal/portal_atlas.png'}


def normalize_png(data: bytes) -> bytes:
    """Réencode un PNG de façon déterministe (l'encodeur de Firefox ne l'est pas à l'octet près).

    Les pixels sont conservés à l'identique (RGBA) ; seules la compression et les métadonnées
    changent. Sans Pillow, le PNG est gardé tel quel (pixels identiques, octets variables).
    """
    try:
        from io import BytesIO
        from PIL import Image
    except ImportError:
        return data
    image = Image.open(BytesIO(data)).convert('RGBA')
    out = BytesIO()
    image.save(out, format='PNG', compress_level=9, optimize=False)
    return out.getvalue()


def safe_join(root: Path, rel: str) -> Path | None:
    """Résout rel sous root ; None si le chemin sort de root."""
    target = (root / rel.lstrip('/')).resolve()
    try:
        target.relative_to(root.resolve())
    except ValueError:
        return None
    return target


def git(src: Path, *args: str) -> bytes:
    """Commande git en lecture seule sur le prototype (aucun verrou optionnel, donc pas d'écriture d'index)."""
    return subprocess.run(['git', '--no-optional-locks', '-C', str(src), *args],
                          capture_output=True, check=True).stdout


class Source:
    """Fichiers du prototype : version figée (git) ou dossier de travail."""

    def __init__(self, src: Path, rev: str):
        self.src, self.rev = src, rev
        self._cache: dict[str, bytes | None] = {}
        if rev != 'WORKTREE':
            self.rev = git(src, 'rev-parse', '--verify', rev + '^{commit}').decode().strip()

    def read(self, rel: str) -> bytes | None:
        rel = rel.lstrip('/')
        if rel in self._cache:
            return self._cache[rel]
        if self.rev == 'WORKTREE':
            target = safe_join(self.src, rel)
            data = target.read_bytes() if target and target.is_file() else None
        else:
            if '..' in Path(rel).parts:
                data = None
            else:
                try:
                    data = git(self.src, 'cat-file', 'blob', f'{self.rev}:{rel}')
                except subprocess.CalledProcessError:
                    data = None
        self._cache[rel] = data
        return data

    def fingerprint(self) -> str:
        """Empreinte des fichiers du jeu : Index.html, ses scripts et l'atlas du portail."""
        index = self.read('Index.html') or b''
        scripts = re.findall(r'<script src="([^"?]+)', index.decode('utf-8', 'replace'))
        h = hashlib.sha1()
        for rel in ['Index.html', *scripts, *IMPORTED]:
            h.update(rel.encode())
            h.update(self.read(rel) or b'')
        return h.hexdigest()


def repo_snapshot(src: Path) -> dict:
    """État observable du dépôt du prototype, pour prouver qu'il n'a pas été modifié."""
    git_dir = src / '.git'
    index = git_dir / 'index'
    return {
        'head': git(src, 'rev-parse', 'HEAD').decode().strip(),
        'refs': hashlib.sha1(git(src, 'for-each-ref')).hexdigest(),
        'worktree': hashlib.sha1(git(src, 'status', '--porcelain', '--untracked-files=all')).hexdigest(),
        'index_mtime_ns': index.stat().st_mtime_ns if index.exists() else None,
    }


class Baker:
    def __init__(self, source: Source, out: Path, page: str):
        self.source, self.out, self.page = source, out, page
        self.written: dict[str, str] = {}
        self.done = threading.Event()
        self.summary: dict = {}
        self.lock = threading.Lock()

    def write(self, rel: str, data: bytes) -> str:
        target = safe_join(self.out, rel)
        if target is None or target.suffix not in ALLOWED_OUT:
            raise PermissionError(rel)
        if target.suffix == '.png':
            data = normalize_png(data)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        digest = hashlib.sha1(data).hexdigest()
        with self.lock:
            self.written[target.relative_to(self.out).as_posix()] = digest
        return digest


def make_handler(baker: Baker):
    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def _send(self, code: int, body: bytes = b'', ctype: str = 'text/plain'):
            self.send_response(code)
            self.send_header('Content-Type', ctype)
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            path = unquote(urlparse(self.path).path)
            if path.startswith('/src/'):
                data, name = baker.source.read(path[5:]), path
            else:
                target = safe_join(BAKER_DIR, path if path != '/' else baker.page)
                data = target.read_bytes() if target and target.is_file() else None
                name = target.name if target else path
            if data is None:
                return self._send(404, b'introuvable')
            ctype = mimetypes.guess_type(name)[0] or 'application/octet-stream'
            if ctype.startswith('text/') or ctype.endswith('javascript'):
                ctype += '; charset=utf-8'
            self._send(200, data, ctype)

        def do_POST(self):
            path = unquote(urlparse(self.path).path)
            body = self.rfile.read(int(self.headers.get('Content-Length', 0)))
            if path == '/log':
                print('  [page]', body.decode('utf-8', 'replace'), flush=True)
                return self._send(204)
            if path == '/done':
                baker.summary = json.loads(body or b'{}')
                self._send(204)
                baker.done.set()
                return
            if path.startswith('/out/'):
                try:
                    digest = baker.write(path[5:], body)
                except PermissionError:
                    return self._send(403, b'ecriture refusee')
                return self._send(200, digest.encode())
            self._send(404)

    return Handler


def launch_firefox(url: str) -> tuple[subprocess.Popen, tempfile.TemporaryDirectory]:
    profile = tempfile.TemporaryDirectory(prefix='baker-firefox-')
    binary = shutil.which('firefox')
    if not binary:
        raise SystemExit('Firefox introuvable dans le PATH.')
    proc = subprocess.Popen(
        [binary, '--headless', '--no-remote', '--profile', profile.name, '--window-size', '1440,900', url],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return proc, profile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--src', type=Path, default=DEFAULT_SRC, help='dépôt du prototype JS (lecture seule)')
    parser.add_argument('--rev', default=REFERENCE_REV, help='commit de référence, ou WORKTREE')
    parser.add_argument('--out', type=Path, default=PROJECT_DIR / 'assets' / 'baked', help='dossier de sortie')
    parser.add_argument('--page', default='bake.html', help='page à exécuter dans tools/baker/')
    parser.add_argument('--port', type=int, default=0)
    parser.add_argument('--timeout', type=float, default=900)
    parser.add_argument('--no-browser', action='store_true')
    parser.add_argument('--keep', action='store_true', help='ne pas vider le dossier de sortie')
    args = parser.parse_args()

    src, out = args.src.resolve(), args.out.resolve()
    if out == src or src in out.parents:
        raise SystemExit('Le dossier de sortie ne peut pas être dans le prototype source.')
    snapshot_before = repo_snapshot(src)
    source = Source(src, args.rev)
    if source.read('Index.html') is None:
        raise SystemExit(f'Index.html introuvable dans {src} @ {source.rev}')
    fingerprint = source.fingerprint()

    if out.exists() and not args.keep:
        # Les fichiers .import de Godot sont conservés : ils portent les UID des ressources.
        for f in sorted(out.rglob('*'), reverse=True):
            if f.is_file() and f.suffix in ALLOWED_OUT:
                f.unlink()
    out.mkdir(parents=True, exist_ok=True)

    baker = Baker(source, out, args.page)
    server = http.server.ThreadingHTTPServer(('127.0.0.1', args.port), make_handler(baker))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f'http://127.0.0.1:{server.server_port}/{args.page}'
    print(f'Baker : {url}\n  source : {src} @ {source.rev}\n  sortie : {out}', flush=True)

    started = time.time()
    proc = profile = None
    if not args.no_browser:
        proc, profile = launch_firefox(url)
    finished = baker.done.wait(args.timeout)
    if proc:
        proc.terminate()
        try:
            proc.wait(10)
        except subprocess.TimeoutExpired:
            proc.kill()
        profile.cleanup()
    server.shutdown()

    if args.page.split('?')[0] == 'bake.html':
        imported_dir = PROJECT_DIR / 'assets' / 'imported'
        for rel_src, rel_dst in IMPORTED.items():
            data = source.read(rel_src)
            dst = imported_dir / rel_dst
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(data)
            baker.written['../imported/' + rel_dst] = hashlib.sha1(data).hexdigest()

    # .import orphelins (image qui n'est plus produite) et dossiers vides.
    for imp in out.rglob('*.import'):
        if not imp.with_suffix('').exists():
            imp.unlink()
    for d in sorted((p for p in out.rglob('*') if p.is_dir()), reverse=True):
        if not any(d.iterdir()):
            d.rmdir()
    snapshot_after = repo_snapshot(src)
    unchanged = snapshot_before == snapshot_after and fingerprint == Source(src, source.rev).fingerprint()
    report = {
        'ok': finished and not baker.summary.get('errors') and unchanged,
        'page': args.page,
        'duration_s': round(time.time() - started, 1),
        'source': str(src),
        'source_rev': source.rev,
        'source_fingerprint': fingerprint,
        'source_unchanged': unchanged,
        'repo_snapshot': snapshot_before,
        'timed_out': not finished,
        'summary': baker.summary,
        'files': dict(sorted(baker.written.items())),
    }
    (out / 'bake_report.json').write_text(json.dumps(report, ensure_ascii=False, indent=1) + '\n')
    print(f"{'OK' if report['ok'] else 'ÉCHEC'} : {len(baker.written)} fichiers en {report['duration_s']} s", flush=True)
    for err in baker.summary.get('errors', []):
        print('  erreur :', err)
    if not unchanged:
        print('  ALERTE : le dépôt du prototype a changé pendant l’exécution.', snapshot_before, snapshot_after)
    if not finished:
        print('  délai dépassé : la page n’a pas signalé la fin (/done).')
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
