# Arquitectura

Plataforma principal: **AWS Amplify Hosting** (frontend) + **AWS App Runner** (API) + **Amazon RDS for PostgreSQL** (persistencia). El pipeline combina Amplify (frontend) y GitHub Actions (backend).

## Diagrama

```mermaid
flowchart LR
    dev([Equipo]) -->|push / PR| gh[(GitHub<br/>develop · qa · main)]

    subgraph CI["CI/CD"]
        gh -->|webhook por rama| amp[AWS Amplify<br/>amplify.yml<br/>npm ci · test · build]
        gh -->|push| gha[GitHub Actions<br/>backend.yml<br/>mvn test · package]
        gha -->|OIDC| iam[IAM role<br/>observatorio-github-actions]
        gha -->|docker push<br/>tag dev/qa/prod| ecr[(Amazon ECR<br/>observatorio-api)]
        gha -->|start-deployment<br/>+ smoke test| ar
    end

    subgraph AWS["AWS us-east-1"]
        subgraph FE["Amplify Hosting · CloudFront · HTTPS"]
            fdev[develop → DEV]
            fqa[qa → QA]
            fprod[main → PDN]
        end
        subgraph ar["App Runner · HTTPS · 0.25 vCPU / 1 GB"]
            adev[observatorio-api-dev]
            aqa[observatorio-api-qa]
            aprod[observatorio-api-prod]
        end
        ecr --> ar
        ar -->|VPC connector<br/>SG observatorio-apprunner-sg| rds
        subgraph VPC["VPC por defecto · subredes privadas para RDS"]
            rds[(RDS PostgreSQL db.t4g.micro<br/>observatorio_dev · observatorio_qa · observatorio_prod)]
        end
        sm[Secrets Manager<br/>observatorio/*/db-password] -.->|inyección en runtime| ar
    end

    amp --> FE
    user([Usuario]) -->|HTTPS| FE
    FE -->|fetch VITE_API_URL| ar
```

## Separación de ambientes

| Ambiente | Rama | Frontend (Amplify) | API (App Runner) | Base de datos | Usuario BD |
|----------|------|--------------------|------------------|---------------|------------|
| DEV | `develop` | `https://develop.<appId>.amplifyapp.com` | `observatorio-api-dev` | `observatorio_dev` | `observatorio_dev` |
| QA | `qa` | `https://qa.<appId>.amplifyapp.com` | `observatorio-api-qa` | `observatorio_qa` | `observatorio_qa` |
| PDN | `main` | `https://main.<appId>.amplifyapp.com` | `observatorio-api-prod` | `observatorio_prod` | `observatorio_prod` |

- Cada ambiente tiene **su propia URL de frontend, su propia API y su propia base de datos con usuario propio**. Un usuario de un ambiente no puede conectarse a la base de otro (`REVOKE ALL ... FROM PUBLIC`).
- Las tres bases viven en **una sola instancia RDS** para mantener el costo dentro del free tier. En un sistema real, PDN tendría su propia instancia (y Multi-AZ).
- El frontend muestra el ambiente en la barra superior (`VITE_APP_ENV`), lo que permite comprobar visualmente que cada URL apunta a un despliegue distinto.

## Configuración por ambiente

| Variable | Dónde se define | DEV / QA / PDN |
|----------|-----------------|----------------|
| `VITE_API_URL` | Amplify, variables por rama | URL HTTPS del App Runner del mismo ambiente |
| `VITE_APP_ENV` | Amplify, variables por rama | `DEV` / `QA` / `PDN` |
| `SPRING_DATASOURCE_URL` | App Runner, variable | `jdbc:postgresql://<rds>:5432/observatorio_<env>` |
| `SPRING_DATASOURCE_USERNAME` | App Runner, variable | `observatorio_<env>` |
| `SPRING_DATASOURCE_PASSWORD` | App Runner, **secreto** (Secrets Manager) | `observatorio/<env>/db-password` |
| `APP_CORS_ORIGINS` | App Runner, variable | URL Amplify de la rama del ambiente |
| `AWS_ROLE_ARN` | GitHub, variable del repositorio | ARN del rol OIDC (no es secreto) |
| `FRONTEND_URL` | GitHub, variable de cada environment | URL Amplify del ambiente (para el smoke test) |

## Flujo de promoción

```mermaid
sequenceDiagram
    participant D as Desarrollador
    participant G as GitHub
    participant A as Amplify
    participant H as GitHub Actions
    participant R as Release Manager
    D->>G: PR feature/* → develop (Frontend CI + pruebas backend)
    G->>A: merge en develop → build + test + deploy DEV
    G->>H: merge en develop → test → imagen dev → App Runner DEV → smoke
    D->>G: PR develop → qa (aprueba QA)
    G->>A: deploy QA
    G->>H: imagen qa → App Runner QA → smoke
    Note over D,G: Aceptación manual en QA (docs/PLAN_PRUEBAS.md)
    D->>G: PR qa → main
    G->>A: deploy PDN
    G->>H: job "production" en espera
    R->>H: Aprobar despliegue
    H->>H: imagen prod → App Runner PDN → smoke
```

Un fallo de `npm test`, `mvn test`, del despliegue o del smoke test detiene el pipeline y la versión no avanza.

## Rollback
- **Frontend:** Amplify > rama > Deployments > elegir un build anterior > *Redeploy this version*.
- **API:** GitHub Actions > *Backend CI/CD* > *Run workflow* en la rama del ambiente con `image_tag = <env>-<sha>` de una versión previa (ver tags en ECR).
- **Código:** `git revert <commit>` y push; el pipeline vuelve a desplegar.
