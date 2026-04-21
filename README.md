# Projeto de Engenharia de Dados — Modern Data Stack

Projeto educacional de engenharia de dados cobrindo toda a stack moderna: ambiente local com Docker, modelagem dimensional com dbt, orquestração com Apache Airflow (Astronomer + Cosmos) e CI/CD com GitHub Actions. O domínio de dados é **atrasos de voos nos EUA** com 318.017 registros históricos.

---

## Visão Geral da Arquitetura

```
CSV Seed (318k rows)
        │
        ▼
┌───────────────────────┐
│  PostgreSQL 17        │  ← Docker local (porta 5433) ou Railway (prod)
└───────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────────────────┐
│                     dbt (dw_bootcamp)                         │
│                                                               │
│  STAGING          INTERMEDIATE              MART              │
│  (views)          (tables)                  (tables)          │
│                                                               │
│  stg_airline  →   int_dim_carrier    →   mart_carrier_perf    │
│  _delay_cause     int_dim_airport    →   mart_airport_perf    │
│                   int_dim_month      →   mart_monthly_kpis    │
│                   int_fct_flight_    →   mart_delay_causes_   │
│                   delays                 share_month          │
│                                          mart_delay_causes_   │
│                                          long                 │
└───────────────────────────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────┐
│  Apache Airflow 3.x (Astronomer)      │
│  Cosmos → dbt tasks automáticos       │
│  Schedule: @daily | Dev & Prod        │
└───────────────────────────────────────┘
        │
        ▼
  Ferramentas de BI / Análise
```

---

## Estrutura de Pastas

```
projeto_eng_dados/
├── 1_local_setup/          # Módulo 1 — Ambiente de desenvolvimento
├── 2_data_warehouse/       # Módulo 2 — Data warehouse com dbt
│   └── dw_bootcamp/        # Projeto dbt principal
│       ├── models/
│       │   ├── staging/
│       │   ├── intermediate/
│       │   └── mart/
│       └── seeds/
├── 3_airflow/              # Módulo 3 — Orquestração com Airflow
│   └── dags/
└── .github/workflows/      # CI/CD com GitHub Actions
```

---

## Módulo 1 — Local Setup

**Localização:** [1_local_setup/](1_local_setup/)

Configura o ambiente de desenvolvimento local com Python e PostgreSQL rodando em Docker.

### Tecnologias

| Ferramenta | Versão | Finalidade |
|---|---|---|
| Python | 3.13 | Linguagem principal |
| UV | — | Gerenciador de pacotes Python |
| PostgreSQL | 17 | Banco de dados |
| Docker Compose | — | Containerização do banco |
| dbt-core | ≥ 1.10.15 | Framework de transformação |
| dbt-postgres | ≥ 1.9.1 | Adapter PostgreSQL para dbt |
| DuckDB | ≥ 1.4.3 | Banco analítico local |
| Pandas | ≥ 2.3.3 | Manipulação de dados |
| NumPy | ≥ 2.3.5 | Computação numérica |
| Faker | ≥ 38.2.0 | Geração de dados sintéticos |

### Configuração do Banco

O [docker-compose.yml](1_local_setup/docker-compose.yml) sobe um PostgreSQL 17:

```yaml
container_name: dbt_postgres
porta: 5433        # mapeado para 5432 interno
database: dbt_db
user: postgres     # configurado via .env
```

### Como iniciar

```bash
cd 1_local_setup

# Subir o banco
docker compose up -d

# Instalar dependências Python
uv sync
```

---

## Módulo 2 — Data Warehouse (dbt)

**Localização:** [2_data_warehouse/dw_bootcamp/](2_data_warehouse/dw_bootcamp/)

Projeto dbt completo com arquitetura em três camadas para análise de atrasos de voos.

### Dado de Origem

**Arquivo:** [seeds/Airline_Delay_Cause.csv](2_data_warehouse/dw_bootcamp/seeds/Airline_Delay_Cause.csv)

| Campo | Descrição |
|---|---|
| year / month | Período do registro |
| carrier / carrier_name | Código e nome da companhia aérea |
| airport / airport_name | Código e nome do aeroporto |
| arr_flights | Total de voos chegados |
| arr_del15 | Voos com atraso ≥ 15 min |
| carrier_ct / weather_ct / nas_ct / security_ct / late_aircraft_ct | Contagem de atrasos por causa |
| carrier_delay / weather_delay / nas_delay / security_delay / late_aircraft_delay | Minutos de atraso por causa |
| arr_cancelled / arr_diverted | Cancelados e desviados |

### Pacotes dbt

| Pacote | Versão | Uso |
|---|---|---|
| dbt-labs/dbt_utils | 1.3.0 | Macros utilitários (surrogate_key, unpivot, etc.) |
| metaplane/dbt_expectations | 0.10.8 | Testes avançados de qualidade de dados |

### Arquitetura de Modelos

#### Camada Staging — `models/staging/` (materialização: **view**)

| Modelo | Descrição |
|---|---|
| `stg_airline_delay_cause` | Cast de tipos, padronização de colunas, criação da chave `year_month_key` (formato YYYYMM) |

Camada leve sem custo de armazenamento, responsável apenas por tipagem e limpeza básica.

#### Camada Intermediate — `models/intermediate/` (materialização: **table**)

| Modelo | Tipo | Descrição |
|---|---|---|
| `int_dim_carrier` | Dimensão | Companhias aéreas únicas com ID e nome |
| `int_dim_airport` | Dimensão | Aeroportos únicos com cidade e nome |
| `int_dim_month` | Dimensão | Meses únicos com chave composta ano+mês |
| `int_fct_flight_delays` | Fato | Tabela fato com todas as métricas de atraso, joins com dimensões |

Implementa a modelagem dimensional (star schema): uma tabela fato central ligada às dimensões.

#### Camada Mart — `models/mart/` (materialização: **table**)

| Modelo | Descrição |
|---|---|
| `mart_carrier_performance` | KPIs agregados por companhia aérea (voos, atrasos, cancelamentos) |
| `mart_airport_performance` | KPIs agregados por aeroporto |
| `mart_monthly_kpis` | Indicadores mensais gerais |
| `mart_delay_causes_share_month` | Participação percentual de cada causa de atraso por mês |
| `mart_delay_causes_long` | Formato longo (unpivot) das causas de atraso — ideal para visualizações |

Tabelas prontas para consumo por ferramentas de BI, pré-agregadas para performance.

### Configurações do Projeto

**Fuso horário:** `America/Sao_Paulo` (configurado via variável `dbt_date:time_zone`)

**Conexão local** ([profiles.yml](2_data_warehouse/dw_bootcamp/profiles.yml)):
```
host: localhost | porta: 5433 | database: dbt_db | schema: public | threads: 4
```

### Como executar o dbt

```bash
cd 2_data_warehouse/dw_bootcamp

# Instalar pacotes
dbt deps

# Carregar dados seed
dbt seed

# Executar todos os modelos
dbt run

# Rodar testes
dbt test

# Pipeline completo
dbt build
```

---

## Módulo 3 — Orquestração com Airflow

**Localização:** [3_airflow/](3_airflow/)

Orquestração do pipeline dbt com Apache Airflow 3.x usando o stack Astronomer + Cosmos.

### Tecnologias

| Ferramenta | Finalidade |
|---|---|
| Apache Airflow 3.x | Orquestrador de workflows |
| Astronomer Runtime | Distribuição enterprise do Airflow |
| Astronomer Cosmos | Converte projetos dbt em DAGs Airflow automaticamente |
| apache-airflow-providers-postgres | Conexões com PostgreSQL |

### Arquitetura do DAG

O arquivo [dags/dag.py](3_airflow/dags/dag.py) usa Cosmos para gerar automaticamente um DAG Airflow a partir do projeto dbt, sem precisar definir tarefa por tarefa manualmente.

**Configurações do DAG:**

| Parâmetro | Valor |
|---|---|
| DAG ID | `dag_dw_bootcamp_dev` ou `dag_dw_bootcamp_prod` |
| Schedule | `@daily` |
| Start Date | 2025-12-15 |
| Catchup | Desabilitado |
| Retries | 2 |

### Ambientes: Dev e Prod

O ambiente é selecionado via Airflow Variable `dbt_env`:

| Ambiente | Conexão Airflow | PostgreSQL |
|---|---|---|
| `dev` | `docker_postgres_db` | Local Docker (porta 5433) |
| `prod` | `railway_postgres_db` | Railway (cloud remoto) |

```bash
# Para alternar ambiente no Airflow UI:
# Admin → Variables → dbt_env = "dev" ou "prod"
```

### Isolamento do dbt no Airflow

O [Dockerfile](3_airflow/Dockerfile) cria um virtualenv Python isolado para o dbt, evitando conflitos de dependências com o Airflow:

```dockerfile
RUN python -m venv dbt_venv \
    && . dbt_venv/bin/activate \
    && pip install --no-cache-dir dbt-postgres==1.9.0
```

### Como iniciar o Airflow

```bash
cd 3_airflow

# Iniciar ambiente Astronomer
astro dev start

# Parar
astro dev stop
```

Airflow UI disponível em: `http://localhost:8080`

---

## CI/CD — GitHub Actions

**Localização:** [.github/workflows/dbt_ci.yml](.github/workflows/dbt_ci.yml)

Pipeline automatizado de validação e teste do projeto dbt em todo push e pull request.

### Jobs

| Job | Comando | Finalidade |
|---|---|---|
| `dbt-compile` | `dbt parse` | Valida sintaxe dos modelos sem executar |
| `dbt-build` | `dbt seed && dbt run && dbt test` | Pipeline completo com banco real |

O job `dbt-build` sobe um serviço PostgreSQL 17 efêmero durante a execução da pipeline.

---

## Stack Completa de Tecnologias

| Categoria | Tecnologia |
|---|---|
| Linguagem | Python 3.13 |
| Banco de dados | PostgreSQL 17 |
| Transformação de dados | dbt-core, dbt-postgres |
| Banco analítico local | DuckDB |
| Orquestração | Apache Airflow 3.x |
| Distribuição Airflow | Astronomer Runtime |
| Integração dbt↔Airflow | Astronomer Cosmos |
| Qualidade de dados | dbt_expectations |
| Utilitários dbt | dbt_utils, dbt_date |
| Containers | Docker, Docker Compose |
| Gerenciador de pacotes | UV |
| CI/CD | GitHub Actions |
| Cloud de banco (prod) | Railway |

---

## Fluxo Completo de Dados

```
1. INGESTÃO
   Airline_Delay_Cause.csv (318.017 linhas)
   └─► dbt seed → tabela raw no PostgreSQL

2. STAGING
   stg_airline_delay_cause
   └─► Cast de tipos, criação de chaves, sem transformação de negócio

3. DIMENSIONAL (Star Schema)
   int_dim_carrier    ─┐
   int_dim_airport    ─┤──► int_fct_flight_delays
   int_dim_month      ─┘

4. MARTS (BI-ready)
   mart_carrier_performance        → Performance por companhia
   mart_airport_performance        → Performance por aeroporto
   mart_monthly_kpis               → KPIs mensais
   mart_delay_causes_share_month   → Share % de causas
   mart_delay_causes_long          → Formato longo para gráficos

5. ORQUESTRAÇÃO
   Airflow (Cosmos) executa dbt build diariamente
   ├─► Dev:  PostgreSQL local Docker
   └─► Prod: PostgreSQL Railway (cloud)
```

---

## Pré-requisitos

- Docker e Docker Compose
- Python 3.13+
- UV (`pip install uv`)
- Astronomer CLI (`curl -sSL https://install.astronomer.io | sudo bash`)
- Git

---

## Quick Start

```bash
# 1. Clonar o repositório
git clone <repo-url>
cd projeto_eng_dados

# 2. Subir o banco local
cd 1_local_setup
docker compose up -d

# 3. Instalar dependências Python
uv sync

# 4. Executar o pipeline dbt
cd ../2_data_warehouse/dw_bootcamp
dbt deps
dbt build

# 5. (Opcional) Subir o Airflow
cd ../../3_airflow
astro dev start
```
