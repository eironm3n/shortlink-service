# shortlink-service

[![CI](https://github.com/eironm3n/shortlink-service/actions/workflows/ci.yml/badge.svg)](https://github.com/eironm3n/shortlink-service/actions/workflows/ci.yml)
[![Container](https://img.shields.io/badge/ghcr.io-shortlink--service-blue?logo=docker)](https://github.com/eironm3n/shortlink-service/pkgs/container/shortlink-service)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](./LICENSE)

Un acortador de URLs mínimo pero real, usado como **pieza de portafolio DevOps**:
lo importante no es el acortador, es *cómo se construye, prueba, empaqueta,
escanea, publica y despliega*.

```
POST /api/links        {"target_url": "https://ejemplo.com/una/pagina/larga"}
      -> 201  {"code": "aB3xK9p", "short_url": ".../aB3xK9p", "visits": 0}

GET  /aB3xK9p          -> 307 Location: https://ejemplo.com/una/pagina/larga
GET  /api/links/aB3xK9p -> {"visits": 1, ...}
GET  /healthz          -> {"status": "ok"}
GET  /version          -> {"version": "<git sha>"}
GET  /metrics          -> métricas Prometheus (rate, latencia, errores por handler)
```

## Arquitectura

```mermaid
flowchart LR
    dev[git push / PR] --> gha[GitHub Actions]

    subgraph gha[CI Pipeline]
        q[quality<br/>ruff · mypy · pytest] --> img[image<br/>build · Trivy · smoke test]
        iac[iac<br/>terraform validate]
    end

    img -->|solo en main| ghcr[(ghcr.io<br/>shortlink-service)]
    ghcr -.->|terraform apply<br/>manual| ls[AWS Lightsail<br/>Container Service]

    subgraph stack[docker compose]
        api[FastAPI + Uvicorn] --> db[(SQLite<br/>/data volume)]
        api -->|/metrics| prom[Prometheus]
        prom --> graf[Grafana]
    end
    ghcr --> api
```

## Qué demuestra este repo

Respuesta directa a "¿cómo se muestra el expertise?": cada competencia está
anclada a un archivo concreto, y todo es **verificable públicamente** (badge de
CI en verde, imagen en GHCR, historial de ejecuciones del pipeline).

| Competencia | Dónde se ve |
|---|---|
| **Contenedores** | [`Dockerfile`](./Dockerfile): build multi-stage, imagen final `slim`, usuario no-root (`uid 1000`), `HEALTHCHECK`, volumen para datos |
| **CI/CD** | [`.github/workflows/ci.yml`](./.github/workflows/ci.yml): 3 jobs — `quality`, `image`, `iac` — con dependencias, caché de capas (`type=gha`) y publicación condicional (`only main`) |
| **Seguridad de la cadena** | Escaneo con **Trivy** en el pipeline · `permissions` mínimos por job · sin secretos propios (sólo `GITHUB_TOKEN`) · contenedor no-root |
| **Infra como código** | [`infra/`](./infra): Terraform para AWS Lightsail (servicio de contenedor + health check), formateado y validado en cada push |
| **Testing** | [`tests/`](./tests): `pytest` con cobertura mínima del 90 % (`--cov-fail-under=90`), fixture de base de datos SQLite en memoria con `StaticPool` |
| **Calidad de código** | `ruff` (lint + formato) y `mypy` (`disallow_untyped_defs`) sobre `app/` |
| **Observabilidad** | `/metrics` (Prometheus) con rate, latencia (histograma) y errores por `handler`; stack **Prometheus + Grafana** en el `compose` con datasource y dashboard aprovisionados ([`monitoring/`](./monitoring)); `/healthz` y `/version` para health checks |
| **12-factor / config** | [`app/config.py`](./app/config.py): toda la config por variables de entorno `SHORTLINK_*` |

## Puesta en marcha

### Con Docker (recomendado)

```bash
docker compose up --build
```

| Servicio | URL | Nota |
|---|---|---|
| API | http://localhost:8000 · docs en `/docs` | el servicio |
| Prometheus | http://localhost:9090 | scrapea `/metrics` cada 5 s |
| Grafana | http://localhost:3000 | login anónimo (Viewer); dashboard **shortlink-service** ya cargado |

Para ver los gráficos moverse, generá tráfico:

```bash
make load          # 60 s de requests mezclando creación, redirects y 404
```

### Local, para desarrollo

```bash
make install     # crea .venv e instala dependencias de dev
make dev         # uvicorn con --reload
make lint        # ruff + mypy
make test        # pytest + cobertura
make docker      # build de la imagen
```

## Pipeline de CI

Cada `push` a `main` y cada Pull Request dispara:

1. **`quality`** — `ruff check`, `ruff format --check`, `mypy app`, `pytest` (falla si la cobertura baja del 90 %).
2. **`image`** — build de la imagen, escaneo con Trivy (falla ante CVE `CRITICAL` con fix disponible), *smoke test* real (levanta el contenedor y valida `healthz` + crear link + redirect). En `main`, además publica `:latest` y `:<sha>` en GHCR.
3. **`iac`** — `terraform fmt -check`, `init` y `validate` sobre `infra/` (sin credenciales de AWS, sin costo).

## Despliegue

La infraestructura está descrita en [`infra/`](./infra). El `apply` es **manual y
opcional** porque un Lightsail Container `nano` cuesta ~USD 7/mes; el detalle
está en [`infra/README.md`](./infra/README.md).

## Decisiones y límites (a propósito)

- **SQLite + volumen** en vez de Postgres: alcanza para la demo y mantiene la
  imagen y el `compose` simples. En producción real iría Postgres + Alembic.
- **Código aleatorio** de 7 caracteres con reintento ante colisión, en vez de
  contador base62: evita exponer el volumen de links y simplifica la concurrencia.
- **Sin auth ni rate limiting**: fuera del alcance de esta pieza; el foco es la
  cadena de build/deploy, no el producto.

## Observabilidad

El servicio expone `/metrics` en formato Prometheus (vía
`prometheus-fastapi-instrumentator`): contador `http_requests_total` y los
histogramas `http_request_duration_seconds` / `http_request_duration_highr_seconds`,
etiquetados por `method`, `status` y `handler`.

El `docker compose` levanta además:

- **Prometheus** ([`monitoring/prometheus.yml`](./monitoring/prometheus.yml)) — scrapea la API cada 5 s.
- **Grafana** ([`monitoring/grafana/`](./monitoring/grafana)) — con datasource y dashboard
  aprovisionados por archivo: 4 paneles (request rate por handler, latencia
  p50/p95/p99, errores 4xx/5xx, total de requests).

> **Captura del dashboard pendiente.** Para generarla: `docker compose up`,
> luego `make load`, abrir Grafana en `http://localhost:3000`, y guardar el
> panel como `docs/grafana.png` (después descomentar la línea de imagen de abajo).
>
> <!-- ![Grafana dashboard](docs/grafana.png) -->

## Roadmap

- [x] Métricas Prometheus (`/metrics`) y dashboard de Grafana en el `compose`
- [ ] Backend Postgres opcional + migraciones con Alembic
- [ ] Backend remoto de Terraform (S3 + DynamoDB lock)
- [ ] Deploy automático a Lightsail desde el pipeline (con `AWS_*` en secrets)
