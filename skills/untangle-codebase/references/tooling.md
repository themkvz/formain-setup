# Skeleton and import-graph tools

Prefer tools the project already has. One-off runners (`npx`, `bunx`, `uvx`) are fine; don't add dependencies. Write output to `.untangle/`. Rerun the import graph after each fix group and compare.

## Any language

- Co-change and churn: `<skill folder>/scripts/cochange.sh ["since"] [top]`. High churn + high co-change % between files in different folders is a hidden link or a feature split by layer.
- Skeleton with Universal Ctags, if installed (`ctags --version` says "Universal Ctags"; the macOS `/usr/bin/ctags` is not it): `ctags -R -x --sort=no --exclude=node_modules --exclude=.git . > .untangle/skeleton.txt`.
- Import edges, rough: `rg -n --no-heading '^\s*(import|from|export .* from|require\(|use |#include)' > .untangle/imports.txt`.

## JavaScript / TypeScript

- Import graph: `npx madge --json --extensions ts,tsx,js,jsx src > .untangle/graph.json`. Add `--ts-config tsconfig.json` for path aliases. `--circular` lists cycles, `--orphans` lists files nothing imports (dead-code candidates; entry points show up too).
- Skeleton: `npx tsc -p . --declaration --emitDeclarationOnly --noEmit false --outDir .untangle/skeleton`. Shows exported signatures only. If the project config refuses it, use ctags.

## Python

Skeleton and imports in one pass, stdlib only:

```bash
python3 - src > .untangle/skeleton.txt <<'EOF'
import ast, pathlib, sys

skip = {"node_modules", "venv", ".venv", "__pycache__", "build", "dist"}
root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
for path in sorted(root.rglob("*.py")):
    parts = path.relative_to(root).parts
    if skip & set(parts) or any(p.startswith(".") for p in parts):
        continue
    try:
        tree = ast.parse(path.read_text(encoding="utf-8", errors="replace"))
    except SyntaxError as e:
        print(f"## {path} (syntax error: {e.msg})")
        continue
    print(f"## {path}")
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            print("  import", ", ".join(a.name for a in node.names))
        elif isinstance(node, ast.ImportFrom):
            print("  from", "." * node.level + (node.module or ""))
        elif isinstance(node, ast.ClassDef):
            print(f"  {node.lineno}: class {node.name}")
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            print(f"  {node.lineno}: def {node.name}({ast.unparse(node.args)})")
EOF
```

## Go

- Import graph: `go list -f '{{.ImportPath}} -> {{join .Imports " "}}' ./... > .untangle/graph.txt`.
- Skeleton: `go doc -all ./<pkg>` per package.

## Rust

- Module graph: `cargo modules dependencies` if `cargo-modules` is installed; otherwise the rough `rg` edges above.
- Crate graph: `cargo tree`.

## JVM (Java, Kotlin)

- Package graph from compiled classes: `jdeps -verbose:package <build output dir or jar>`.
