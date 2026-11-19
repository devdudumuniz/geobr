# Fork devdudumuniz/geobr — receita Windows

Este arquivo existe só no fork `devdudumuniz/geobr` e não deve ir em PR para `ipea/geobr`.
Ele descreve como recuperar, preparar, verificar e empacotar o fork em um Windows limpo, sem
depender de nenhum outro diretório da máquina de origem.

## Branches

| Branch | Conteúdo |
|---|---|
| `main` | `ipea/geobr` `master` + contribuições ainda não aceitas upstream (issue #444: códigos de 6 dígitos em `lookup_muni`, R e Python). |
| `master` | espelho do `master` upstream; base para novas PRs ao `ipea/geobr`. |
| `contrib/oss-m04-six-digit` | contribuição R (commit `351ad66`), base de uma futura PR upstream. |
| `contrib/oss-m04-pr460-review-fixes` | PR upstream #460 (ArthurFachel, `3d11167`) + correção de revisão `fb7daeb`. |

Novas PRs ao upstream partem de `upstream/master`, nunca de `main`.

## 1. Clonar

```powershell
git clone https://github.com/devdudumuniz/geobr.git
cd geobr
git switch main
git remote add upstream https://github.com/ipea/geobr.git
git fetch upstream master
```

## 2. Preparar

Pré-requisitos: Git, Python 3.10+ com [uv](https://docs.astral.sh/uv/), R 4.x com Rtools (só para o pacote R).
Caches ficam onde a máquina mandar; para não poluir o checkout, defina-os fora dele, por exemplo:

```powershell
$env:UV_CACHE_DIR = "$env:LOCALAPPDATA\uv\cache"   # opcional; qualquer pasta fora do checkout
```

Python:

```powershell
cd python-package
uv sync --frozen          # cria python-package\.venv a partir do uv.lock
```

R (uma vez por máquina):

```powershell
Rscript -e "install.packages(c('pak')); pak::local_install_deps('r-package', dependencies = TRUE)"
```

Proxy: se a rede exigir proxy, exporte `http_proxy`/`https_proxy` apenas quando ele responder
(veja `CLAUDE.md`, seção Commands). Um proxy morto no ambiente faz as chamadas expirarem.

## 3. Verificar (offline, sem baixar dados)

Os testes abaixo não baixam dados espaciais. Testes marcados `network` e exemplos que leem
`read_*()` acessam servidores públicos; só rode-os de propósito e com volume controlado.

```powershell
cd python-package
uv run pytest -n 2 -m "not network"
uv run pytest tests/test_lookup_muni.py -m "not network"
```

```powershell
# Sem NOT_CRAN=true, skip_on_cran() pula os testes que leem dados remotos.
Remove-Item Env:NOT_CRAN -ErrorAction SilentlyContinue
Rscript -e "pkgload::load_all('r-package'); testthat::test_dir('r-package/tests/testthat', filter = 'lookup_muni-code', load_package = 'none')"
Rscript -e "pkgload::load_all('r-package'); testthat::test_dir('r-package/tests/testthat', load_package = 'none')"
```

`devtools::test('r-package')` define `NOT_CRAN=true` e, portanto, roda também os testes com rede;
use-o só quando o acesso aos dados públicos for intencional. Contagens de `SKIP` não contam como aprovação.

## 4. Build

```powershell
cd python-package
uv build                     # dist\geobr-*.whl e *.tar.gz (dist/ é ignorado pelo Git)
```

```powershell
R CMD build r-package
R CMD check --no-manual geobr_*.tar.gz
```

## 5. Start (smoke)

geobr é uma biblioteca; não há serviço para iniciar. O smoke é importar e chamar uma função
local sem rede:

```powershell
cd python-package
uv run python -c "import geobr; print(geobr.__name__, 'ok')"
```

```powershell
Rscript -e "devtools::load_all('r-package'); print(exists('lookup_muni'))"
```

## Recuperação

O fork no GitHub é a fonte de recuperação: `git clone` + passos 2 a 5 reconstroem tudo.
Nenhum dado espacial, `.venv`, `dist/` ou cache faz parte do repositório.
