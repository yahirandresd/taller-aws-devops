# Observatorio de Lluvias y Eventos de Manizales

Aplicación de demostración para el taller Laboratorio DevOps. Incluye frontend React + Vite, API REST Spring Boot y PostgreSQL mediante Docker Compose.

> Los datos iniciales son ficticios y sirven únicamente para pruebas académicas. No es un sistema oficial de alertas ni debe usarse para decisiones de emergencia.

## Componentes
- `frontend/`: React + Vite, dashboard y formularios.
- `backend/`: Java 17 + Spring Boot + Spring Data JPA.
- `docker-compose.yml`: PostgreSQL, API y frontend para ejecución local.
- `Jenkinsfile`: pipeline de referencia para compilar/probar y desplegar por ambiente. Los scripts de despliegue deben ajustarse al proveedor elegido.

## Ejecutar localmente con Docker
Requisitos: Docker Desktop y Docker Compose.

```bash
docker compose up --build
```
- Frontend: http://localhost:5173
- API: http://localhost:8080/api/dashboard/summary
- Health: http://localhost:8080/actuator/health

Para detener:
```bash
docker compose down
```
Para borrar también la base de datos local:
```bash
docker compose down -v
```

## Ejecutar sin Docker
### Backend
Requisitos: Java 17+, Maven 3.9+, PostgreSQL 15+.
Configurar variables `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` y ejecutar:
```bash
cd backend
mvn spring-boot:run
```

### Frontend
Requisitos: Node.js 20+.
```bash
cd frontend
npm install
npm run dev
```
Por defecto, Vite usa `http://localhost:8080` como API. Para otro destino, crear `frontend/.env.local`:
```env
VITE_API_URL=http://localhost:8080
```

## Ambientes DEV, QA y PDN
La app permite configurar la URL de API con `VITE_API_URL`. Despliegue tres copias del frontend con valores distintos, y tres API/base de datos aisladas:
- DEV: frontend DEV → API DEV → DB DEV
- QA: frontend QA → API QA → DB QA
- PDN: frontend PDN → API PDN → DB PDN

En Amplify o Firebase Hosting, configurar variables de entorno por rama/ambiente. Con Jenkins, definir los destinos y secretos en credenciales del servidor. No reutilizar la misma URL para los tres ambientes.

## Funcionalidades
- Registrar precipitación en milímetros por fecha y sector.
- Consultar registros de lluvia y acumulado diario.
- Registrar incidentes de congestión vehicular.
- Registrar reportes de deslizamientos.
- Ver resumen diario: lluvia acumulada, cantidad de incidentes y deslizamientos.
- Filtrar listados por fecha.

## Unidades
Se almacena precipitación en mm. El volumen estimado en litros solo se calcula si se proporciona el área de referencia en m²:
`litros_estimados = precipitación_mm × área_m²`.
No se debe presentar el resultado como volumen real de toda Manizales sin definir el área y la metodología.

## Seguridad antes de publicar
Este repositorio es una base académica, no una solución de producción endurecida. Antes de exponerla:
- Añadir autenticación/autorización para crear, editar y eliminar reportes.
- Usar HTTPS y secretos administrados por el proveedor.
- Configurar CORS con orígenes permitidos específicos.
- Configurar backups, límites de recursos y alertas de costos.
- No abrir PostgreSQL a Internet.
