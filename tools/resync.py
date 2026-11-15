#!/usr/bin/env python3
"""Procédure R — resynchronisation avec une nouvelle version du prototype (MIGRATION_PLAN.md v2, étape 10).

Usage :
    python3 tools/resync.py <nouvelle_rev>              # rapport complet (avec re-extraction par le baker)
    python3 tools/resync.py <nouvelle_rev> --no-bake    # fichiers et fonctions JS seulement (rapide)
    python3 tools/resync.py WORKTREE                    # dossier de travail du prototype
    python3 tools/resync.py <rev> --base <autre_rev>    # comparer à une autre base que la version figée

Produit, dans tools/resync_out/<rev courte>/ :
- RAPPORT.md et rapport.json :
  1. fichiers du jeu modifiés (Index.html et les scripts qu'il charge), et autres fichiers du dépôt ;
  2. fonctions et déclarations JS ajoutées, retirées ou modifiées, avec les fichiers Godot qui les citent ;
  3. sorties du baker qui changent (graphismes, HUD, combat, emplacements, minicarte) ;
  4. références visuelles qui changent ;
  5. étapes du plan à rouvrir (proposition, à décider ensemble) ;
- les extractions brutes de la nouvelle version (bake/, hud/, reference/), pour inspection.

Sécurité : le prototype n'est lu que par git (rev-parse, diff, cat-file, ls-tree), sans verrou optionnel ;
le baker (tools/baker/serve.py) vérifie en plus que le dépôt est identique avant et après. Rien n'est
écrit dans le projet Godot hors de tools/resync_out/.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools' / 'baker'))
from serve import DEFAULT_SRC, REFERENCE_REV, Source, git  # noqa: E402

OUT_ROOT = ROOT / 'tools' / 'resync_out'

# Fichier du prototype → étapes du plan v2 qui l'ont migré.
FILE_STEPS = [
    (r'assets/galleries\.js', [3]),
    (r'assets/decor(-renderer)?\.js', [2]),
    (r'assets/wind\.js', [2, 4]),
    (r'assets/portal\.js', [4]),
    (r'assets/lighting\.js', [4]),
    (r'assets/engineer\.js', [5]),
    (r'assets/units\.js', [5, 9]),
    (r'assets/hud\.js', [6]),
    (r'assets/dialogue\.js', [6]),
    (r'assets/(buildings|adept-sprites|pixel-buildings|temple[a-z-]*|foundry[a-z-]*|sawmill[a-z-]*|barracks[a-z-]*)\.js', [7]),
    (r'assets/adepts\.js', [7, 8]),
    (r'assets/(enemies|turret-game|ballista[a-z-]*)\.js', [8]),
    (r'assets/combat\.js', [8, 9]),
    (r'assets/.*\.(png|jpg|gif|webp)', [1]),
]
# Dossier Godot → étape qui l'a écrit (pour les fonctions d'Index.html, réparties partout).
DIR_STEPS = [
    ('world/terrain/', 3), ('world/decor/', 2), ('world/camera/', 2), ('fx/', 2), ('world/lighting/', 4),
    ('world/ambiance/', 4), ('world/overlay/', 7), ('world/', 2), ('entities/building/', 7), ('entities/turret/', 8),
    ('entities/unit/', 5), ('sim/combat.gd', 8), ('sim/enemy.gd', 8), ('sim/building.gd', 7), ('sim/', 5),
    ('ui/hud/', 6), ('ui/minimap/', 6), ('ui/dialogue/', 6), ('ui/input/', 5), ('data/', 7), ('autoload/', 5),
]
# Page du baker → dossier de référence (contenu comparé) et dossier exclu de la comparaison. La planche du
# décor (decor_atlas*, tools/baker/decor_atlas.py) est dérivée des sprites : elle n'est pas comparée, mais
# toute différence des sprites du décor signale qu'il faut la reconstruire.
PAGES = [
    ('bake.html', ROOT / 'assets' / 'baked', {'hud'}),
    ('hud.html', ROOT / 'assets' / 'baked' / 'hud', set()),
    ('reference.html', ROOT / 'tests' / 'visual' / 'reference', set()),
]
IGNORED_JSON_KEYS = {'duration_s', 'page_seconds', 'generated_at', 'date', 'source_rev', 'source_fingerprint',
                     'repo_before', 'repo_after', 'elapsed', 'seconds'}


# ---------------------------------------------------------------- Fichiers

def game_files(source: Source) -> list[str]:
    index = (source.read('Index.html') or b'').decode('utf-8', 'replace')
    return ['Index.html', *re.findall(r'<script src="([^"?]+)', index)]


def changed_files(src: Path, base: str, new: str) -> list[tuple[str, str]]:
    args = ['diff', '--name-status', '-M', base] + ([] if new == 'WORKTREE' else [new])
    out = git(src, *args).decode('utf-8', 'replace')
    rows = []
    for line in out.splitlines():
        parts = line.split('\t')
        rows.append((parts[0][0], parts[-1]))
    if new == 'WORKTREE':
        for rel in git(src, 'ls-files', '--others', '--exclude-standard').decode().splitlines():
            rows.append(('A', rel))
    return rows


# ---------------------------------------------------------------- Déclarations JS

DECL = re.compile(r'(?:async\s+)?function\s*\*?\s*([A-Za-z_$][\w$]*)|class\s+([A-Za-z_$][\w$]*)|'
                  r'(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=|([A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)+)\s*=(?!=)')
REGEX_PREV = set('(,=:[!&|?{};+-*%<>~^')


def scan_statements(code: str) -> list[tuple[int, int]]:
    """Découpe le code en instructions de premier niveau (début, fin), en ignorant chaînes, gabarits,
    commentaires et expressions régulières. Une instruction finit sur « ; » de profondeur 0, sur
    l'accolade fermante d'une fonction ou d'une classe, ou sur un saut de ligne de profondeur 0 suivi
    d'un nouveau mot-clé de déclaration."""
    out = []
    i, n, depth = 0, len(code), 0
    start = None
    prev = ';'
    head = ''
    while i < n:
        c = code[i]
        if start is None:
            if c.isspace():
                i += 1
                continue
            if code.startswith('//', i):
                j = code.find('\n', i)
                i = n if j < 0 else j + 1
                continue
            if code.startswith('/*', i):
                j = code.find('*/', i + 2)
                i = n if j < 0 else j + 2
                continue
            start = i
            head = code[i:i + 40]
        if code.startswith('//', i):
            j = code.find('\n', i)
            i = n if j < 0 else j
            continue
        if code.startswith('/*', i):
            j = code.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        if c in '"\'`':
            i = skip_string(code, i)
            prev = 'a'
            continue
        if c == '/' and prev in REGEX_PREV:
            i = skip_regex(code, i)
            prev = 'a'
            continue
        if c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
            if depth == 0 and c == '}' and re.match(r'(async\s+)?(function|class)\b', head):
                # fin d'une fonction ou d'une classe, sauf si l'expression continue (appel, opérateur)
                k = i + 1
                while k < n and code[k] in ' \t':
                    k += 1
                if k >= n or code[k] not in '(.,)?:+-*/&|=':
                    out.append((start, i + 1))
                    start = None
                    prev = ';'
                    i += 1
                    continue
        elif c == ';' and depth == 0:
            out.append((start, i + 1))
            start = None
            prev = ';'
            i += 1
            continue
        elif c == '\n' and depth == 0 and start is not None:
            rest = code[i + 1:i + 60].lstrip()
            if prev not in REGEX_PREV and re.match(r'(async\s+function|function|class|const|let|var)\b', rest):
                out.append((start, i))
                start = None
                prev = ';'
                i += 1
                continue
        if not c.isspace():
            prev = c
        i += 1
    if start is not None and code[start:].strip():
        out.append((start, n))
    return out


def skip_string(code: str, i: int) -> int:
    q = code[i]
    i += 1
    depth = 0
    while i < len(code):
        c = code[i]
        if c == '\\':
            i += 2
            continue
        if q == '`' and code.startswith('${', i):
            depth += 1
            i += 2
            continue
        if q == '`' and c == '}' and depth:
            depth -= 1
        elif c == q and not depth:
            return i + 1
        i += 1
    return i


def skip_regex(code: str, i: int) -> int:
    i += 1
    cls = False
    while i < len(code) and code[i] != '\n':
        c = code[i]
        if c == '\\':
            i += 2
            continue
        if c == '[':
            cls = True
        elif c == ']':
            cls = False
        elif c == '/' and not cls:
            i += 1
            while i < len(code) and (code[i].isalpha()):
                i += 1
            return i
        i += 1
    return i


def norm(text: str) -> str:
    return re.sub(r'\s+', ' ', text).strip()


def declarations(name: str, code: str) -> dict[str, str]:
    """{nom : texte normalisé} des déclarations de premier niveau, et des fonctions nommées de second
    niveau (nom qualifié Parent.fonction) pour les modules en IIFE (UnitKit, CombatKit…)."""
    out: dict[str, str] = {}
    anon = 0
    for a, b in scan_statements(code):
        text = code[a:b]
        m = DECL.match(text.lstrip())
        if m:
            key = next(g for g in m.groups() if g)
        else:
            anon += 1
            # Module en IIFE : nommé d'après ce qu'il exporte (global.X = …, window.X = …).
            exp = re.search(r'\b(?:global|window)\.([A-Za-z_$][\w$]*)\s*=', text) if re.match(r'\s*[(!;]', text) else None
            key = f'{exp.group(1)} (module)' if exp else f'⟨instruction : {norm(text)[:48]}⟩'
        k, dup = key, 2
        while k in out:
            k = f'{key} #{dup}'
            dup += 1
        out[k] = norm(text)
        if len(text) > 400:
            # Fonctions nommées internes (modules), au premier niveau d'imbrication du corps.
            inner = text[text.find('{') + 1:] if '{' in text else ''
            for name2, body in inner_functions(inner):
                out.setdefault(f"{key.split(' (')[0]}.{name2}", norm(body))
    return out


def inner_functions(code: str) -> list[tuple[str, str]]:
    """Fonctions et constantes nommées au premier niveau d'un corps de module."""
    res = []
    for a, b in scan_statements(code):
        text = code[a:b]
        m = re.match(r'\s*(?:(?:async\s+)?function\s*([A-Za-z_$][\w$]*)|(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=)', text)
        if m:
            res.append((m.group(1) or m.group(2), text))
    return res


def js_units(source: Source, rel: str) -> dict[str, str]:
    data = source.read(rel)
    if data is None:
        return {}
    text = data.decode('utf-8', 'replace')
    if rel.endswith('.html'):
        out = {}
        for k, m in enumerate(re.finditer(r'<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>', text, re.S)):
            for name, body in declarations(rel, m.group(1)).items():
                out[name if name not in out else f'{name} (script {k + 1})'] = body
        return out
    return declarations(rel, text)


def diff_functions(base: Source, new: Source, files: list[str]) -> list[dict]:
    rows = []
    for rel in files:
        a, b = js_units(base, rel), js_units(new, rel)
        for name in sorted(set(a) | set(b)):
            if name in a and name in b:
                if a[name] == b[name]:
                    continue
                sm = difflib.SequenceMatcher(None, a[name], b[name], autojunk=False)
                rows.append({'file': rel, 'name': name, 'change': 'modifiée', 'size': [len(a[name]), len(b[name])],
                             'similarity': round(sm.ratio(), 3)})
            elif name in b:
                rows.append({'file': rel, 'name': name, 'change': 'ajoutée', 'size': [0, len(b[name])]})
            else:
                rows.append({'file': rel, 'name': name, 'change': 'retirée', 'size': [len(a[name]), 0]})
    return rows


# ---------------------------------------------------------------- Correspondance Godot

def gd_files() -> dict[str, str]:
    out = {}
    for p in ROOT.rglob('*.gd'):
        rel = p.relative_to(ROOT).as_posix()
        if rel.startswith(('addons/', '.godot/')):
            continue
        out[rel] = p.read_text('utf-8', 'replace')
    return out


def snake(name: str) -> str:
    return re.sub(r'(?<=[a-z0-9])([A-Z])', r'_\1', name).lower()


def godot_refs(name: str, gd: dict[str, str]) -> list[str]:
    base = name.split(' ')[0].split('.')[-1]
    if base.startswith('⟨') or len(base) < 4:
        return []
    pats = [re.compile(r'\b' + re.escape(base) + r'\b')]
    if snake(base) != base.lower() or len(base) >= 6:
        pats.append(re.compile(r'\b' + re.escape(snake(base)) + r'\b'))
    hits = [rel for rel, text in gd.items() if any(p.search(text) for p in pats)]
    hits.sort(key=lambda r: (r.startswith('tests/'), r))
    return hits


def steps_for_file(rel: str) -> set[int]:
    for pat, steps in FILE_STEPS:
        if re.fullmatch(pat, rel):
            return set(steps)
    return set()


def steps_for_godot(files: list[str]) -> set[int]:
    res = set()
    for f in files:
        if f.startswith('tests/'):
            continue
        for prefix, step in DIR_STEPS:
            if f.startswith(prefix):
                res.add(step)
                break
    return res


# ---------------------------------------------------------------- Baker

def run_baker(src: Path, rev: str, page: str, out: Path) -> dict:
    if out.exists():
        shutil.rmtree(out)
    cmd = [sys.executable, str(ROOT / 'tools' / 'baker' / 'serve.py'), '--src', str(src), '--rev', rev,
           '--page', page, '--out', str(out)]
    p = subprocess.run(cmd, capture_output=True, text=True)
    return {'page': page, 'ok': p.returncode == 0, 'tail': (p.stdout + p.stderr).strip().splitlines()[-3:]}


def compare_dirs(cur: Path, new: Path, exclude: set[str]) -> list[dict]:
    rows = []
    def files(d: Path) -> set[str]:
        if not d.exists():
            return set()
        return {p.relative_to(d).as_posix() for p in d.rglob('*') if p.is_file() and p.suffix in ('.png', '.json')
                and p.relative_to(d).parts[0] not in exclude and p.name != 'bake_report.json'
                and not p.name.startswith('decor_atlas')}
    a, b = files(cur), files(new)
    for rel in sorted(a | b):
        if rel not in b:
            rows.append({'file': rel, 'change': 'disparaît'})
        elif rel not in a:
            rows.append({'file': rel, 'change': 'nouveau'})
        else:
            d = diff_file(cur / rel, new / rel)
            if d:
                rows.append({'file': rel, 'change': 'modifié', **d})
    return rows


def diff_file(a: Path, b: Path) -> dict | None:
    if a.read_bytes() == b.read_bytes():
        return None
    if a.suffix == '.json':
        ja, jb = json.loads(a.read_text('utf-8')), json.loads(b.read_text('utf-8'))
        paths = json_diff(ja, jb, '')
        return {'json_paths': paths[:12], 'json_count': len(paths)} if paths else None
    try:
        from PIL import Image, ImageChops
    except ImportError:
        return {'pixels': 'inconnu (Pillow absent)'}
    ia, ib = Image.open(a).convert('RGBA'), Image.open(b).convert('RGBA')
    if ia.size != ib.size:
        return {'size': [list(ia.size), list(ib.size)]}
    diff = ImageChops.difference(ia, ib)
    # getbbox() d'une image RGBA ne regarde que l'alpha : différence évaluée sur les quatre canaux.
    boxes = [b for b in (diff.convert('RGB').getbbox(), diff.getchannel('A').getbbox()) if b]
    bbox = [min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes)] if boxes else None
    if bbox is None:
        return None
    px = sum(1 for v in diff.getdata() if any(v))
    return {'pixels': px, 'ratio': round(px / (ia.size[0] * ia.size[1]), 5), 'bbox': bbox}


def json_diff(a, b, path: str) -> list[str]:
    if isinstance(a, dict) and isinstance(b, dict):
        out = []
        for k in sorted(set(a) | set(b), key=str):
            if k in IGNORED_JSON_KEYS:
                continue
            if k not in a or k not in b:
                out.append(f'{path}/{k}')
            else:
                out += json_diff(a[k], b[k], f'{path}/{k}')
        return out
    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            return [f'{path}[{len(a)}→{len(b)}]']
        out = []
        for i, (x, y) in enumerate(zip(a, b)):
            out += json_diff(x, y, f'{path}[{i}]')
        return out
    if isinstance(a, float) or isinstance(b, float):
        return [] if isinstance(a, (int, float)) and isinstance(b, (int, float)) and abs(a - b) < 1e-9 else [path]
    return [] if a == b else [path]


# ---------------------------------------------------------------- Rapport

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('rev', help='nouvelle version du prototype (commit, branche) ou WORKTREE')
    ap.add_argument('--base', default=REFERENCE_REV, help='version figée actuelle (défaut : référence de la migration)')
    ap.add_argument('--src', type=Path, default=DEFAULT_SRC)
    ap.add_argument('--no-bake', action='store_true', help='ne pas relancer le baker')
    ap.add_argument('--out', type=Path)
    args = ap.parse_args()

    base, new = Source(args.src, args.base), Source(args.src, args.rev)
    tag = 'WORKTREE' if new.rev == 'WORKTREE' else new.rev[:7]
    out = args.out or OUT_ROOT / tag
    out.mkdir(parents=True, exist_ok=True)
    report: dict = {'base': base.rev, 'rev': new.rev, 'src': str(args.src),
                    'fingerprint': [base.fingerprint(), new.fingerprint()]}
    log = git(args.src, 'log', '--oneline', f'{base.rev}..{new.rev}').decode().splitlines() if new.rev != 'WORKTREE' else []
    report['commits'] = log

    game = sorted(set(game_files(base)) | set(game_files(new)))
    files = changed_files(args.src, base.rev, new.rev)
    report['files_game'] = [{'status': s, 'file': f, 'steps': sorted(steps_for_file(f))} for s, f in files if f in game]
    report['files_other'] = [{'status': s, 'file': f} for s, f in files if f not in game]
    loaded = [f for f in game if any(f == r['file'] for r in report['files_game'])]
    gd = gd_files()
    funcs = diff_functions(base, new, [f for f in loaded if f.endswith(('.js', '.html'))])
    for r in funcs:
        r['godot'] = godot_refs(r['name'], gd)
    report['functions'] = funcs

    report['bake'] = []
    if not args.no_bake:
        for page, cur, exclude in PAGES:
            dest = out / Path(page).stem
            print(f'baker : {page} sur {tag}…', flush=True)
            run = run_baker(args.src, new.rev, page, dest)
            run['changes'] = compare_dirs(cur, dest, exclude) if run['ok'] else []
            report['bake'].append(run)

    steps: dict[int, list[str]] = {}
    for r in report['files_game']:
        for s in r['steps']:
            steps.setdefault(s, []).append(f"fichier {r['file']}")
    for r in funcs:
        if r['file'] == 'Index.html' or not steps_for_file(r['file']):
            for s in steps_for_godot(r['godot']):
                steps.setdefault(s, []).append(f"{r['name']} ({r['change']})")
    for run in report['bake']:
        if not run['ok']:
            steps.setdefault(1, []).append(f"baker : {run['page']} ne s'exécute plus")
        for c in run['changes']:
            if run['page'] == 'bake.html':
                steps.setdefault(1, []).append(f"extraction {c['file']}")
            elif run['page'] == 'reference.html' and c['file'].endswith('.png'):
                m = re.match(r'etape(\d+)_', c['file'])
                if m:
                    steps.setdefault(int(m.group(1)), []).append(f"référence {c['file']}")
            elif run['page'] == 'hud.html':
                steps.setdefault(6 if 'hud_' in c['file'] or 'portraits' in c['file'] or 'minimap' in c['file'] else 8, []).append(
                    f"référence {c['file']}")
    report['steps'] = {str(k): sorted(set(v)) for k, v in sorted(steps.items())}

    (out / 'rapport.json').write_text(json.dumps(report, ensure_ascii=False, indent=1), 'utf-8')
    (out / 'RAPPORT.md').write_text(render(report, tag, args.no_bake), 'utf-8')
    print(f'Rapport : {(out / "RAPPORT.md").relative_to(ROOT)}')
    print(f"{len(report['files_game'])} fichier(s) du jeu, {len(funcs)} déclaration(s) JS, "
          f"{sum(len(r['changes']) for r in report['bake'])} sortie(s) du baker modifiée(s), "
          f"étapes à rouvrir : {', '.join(report['steps']) or 'aucune'}")
    return 0 if all(r['ok'] for r in report['bake']) else 1


def render(r: dict, tag: str, no_bake: bool) -> str:
    L = [f"# Resynchronisation — {r['base'][:7]} → {tag}", '',
         f"Prototype : `{r['src']}`. Empreinte des fichiers du jeu : `{r['fingerprint'][0][:12]}` → `{r['fingerprint'][1][:12]}`"
         + (' (identique)' if r['fingerprint'][0] == r['fingerprint'][1] else '') + '.', '']
    if r['commits']:
        L += ['## Commits', ''] + [f'- `{c}`' for c in r['commits']] + ['']
    L += ['## 1. Fichiers du jeu modifiés', '']
    if r['files_game']:
        L += ['| État | Fichier | Étapes |', '|---|---|---|']
        L += [f"| {x['status']} | `{x['file']}` | {', '.join(map(str, x['steps'])) or 'selon les fonctions'} |" for x in r['files_game']]
    else:
        L.append('Aucun.')
    if r['files_other']:
        L += ['', f"Autres fichiers du dépôt ({len(r['files_other'])}) : "
              + ', '.join(f"`{x['file']}` ({x['status']})" for x in r['files_other'][:30])
              + (' …' if len(r['files_other']) > 30 else '')]
    L += ['', '## 2. Déclarations JS', '']
    if r['functions']:
        L += ['| Fichier | Déclaration | Changement | Taille | Fichiers Godot qui la citent |', '|---|---|---|---|---|']
        for f in r['functions']:
            size = f"{f['size'][0]} → {f['size'][1]}" + (f" ({round(100 * f['similarity'])} % semblable)" if 'similarity' in f else '')
            godot = ', '.join(f'`{g}`' for g in f['godot'][:5]) + (' …' if len(f['godot']) > 5 else '')
            L.append(f"| `{f['file']}` | `{f['name']}` | {f['change']} | {size} | {godot or '—'} |")
    else:
        L.append('Aucune.')
    L += ['', '## 3–4. Sorties du baker et références visuelles', '']
    if no_bake:
        L.append('Non relancé (`--no-bake`).')
    for run in r['bake']:
        L.append(f"### `{run['page']}` — {'ok' if run['ok'] else 'ÉCHEC : ' + ' / '.join(run['tail'])}")
        L.append('')
        if not run['ok']:
            L += ["Extraction impossible : la page du baker s'appuie sur des variables ou fonctions du prototype "
                  "absentes ou changées dans cette version. Adapter le baker (étape 1) avant de comparer.", '']
            continue
        if not run['changes']:
            L += ['Aucune différence.', '']
            continue
        L += ['| Fichier | Changement | Détail |', '|---|---|---|']
        for c in run['changes']:
            detail = ''
            if 'pixels' in c:
                detail = f"{c['pixels']} pixels ({100 * c['ratio']:.2f} %), zone {c['bbox']}" if isinstance(c['pixels'], int) else c['pixels']
            elif 'json_paths' in c:
                detail = f"{c['json_count']} valeur(s) : " + ', '.join(f'`{p}`' for p in c['json_paths'][:6])
            elif 'size' in c:
                detail = f"taille {c['size'][0]} → {c['size'][1]}"
            L.append(f"| `{c['file']}` | {c['change']} | {detail} |")
        L.append('')
    L += ['', '## 5. Étapes à rouvrir (proposition)', '']
    if r['steps']:
        for k, why in r['steps'].items():
            L.append(f"- **Étape {k}** : " + '; '.join(why[:8]) + (f' (+{len(why) - 8})' if len(why) > 8 else ''))
    else:
        L.append('Aucune : la migration reste à jour.')
    L += ['', 'À décider ensemble avant toute modification (MIGRATION_PLAN.md §9, règle 6).', '']
    return '\n'.join(L)


if __name__ == '__main__':
    sys.exit(main())
