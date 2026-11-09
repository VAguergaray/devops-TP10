# TP10C - Helm Continuous Delivery

## Descripción

Este proyecto implementa un esquema de Continuous Delivery (CD) utilizando Helm y Kubernetes, con dos entornos independientes: Staging y Producción.

El objetivo es validar los manifiestos antes del despliegue, automatizar las actualizaciones de las aplicaciones y contemplar mecanismos de rollback ante fallos.

## Tecnologías utilizadas

- Kubernetes
- Helm 3
- Docker
- Kind
- GitHub Actions
- Python 3
- PyYAML
- Bash

## Arquitectura

La aplicación está compuesta por:

- Backend: API desarrollada en Python.
- Frontend: servidor web Nginx.
- PostgreSQL: base de datos.
- Services: comunicación interna entre componentes.
- PersistentVolumeClaim: almacenamiento persistente.
- Ingress: acceso HTTP a la aplicación.
- HorizontalPodAutoscaler: escalado automático del backend en Producción.

## Entornos

| Característica | Staging | Producción |
|---|---|---|
| Release Helm | notes-staging | notes-production |
| Namespace | staging-tp10c | production-tp10c |
| Backend replicas | 1 | 3 |
| Frontend replicas | 1 | 3 |
| PostgreSQL | 1 | 1 |
| PVC | 1 Gi | 5 Gi |
| HPA | Deshabilitado | Habilitado |
| Host Ingress | staging.devops-portfolio.local | devops-portfolio.com |

## Estructura del proyecto

```text
devops-TP10/
├── .github/
│   └── workflows/
│       ├── pr-check.yml
│       └── helm-cd.yml
├── devops-portfolio/
│   ├── templates/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-staging.yaml
│   └── values-prod.yaml
├── scripts/
│   ├── render-validate.sh
│   └── verificar-helm-entornos.sh
└── README.md
```

## 1. Validación previa al despliegue

Ejecutar:

```bash
./scripts/render-validate.sh
```

El script realiza:

1. Helm lint.
2. Renderizado de manifiestos para Staging.
3. Renderizado de manifiestos para Producción.
4. Validación de sintaxis YAML mediante Python y PyYAML.
5. Kubernetes dry-run para ambos entornos.

El despliegue debe realizarse únicamente después de superar estas validaciones.

## 2. Despliegue en Staging

```bash
helm upgrade --install notes-staging ./devops-portfolio \
  --namespace staging-tp10c \
  --create-namespace \
  -f devops-portfolio/values-staging.yaml
```

Verificar:

```bash
helm status notes-staging -n staging-tp10c
kubectl get pods -n staging-tp10c
kubectl get services -n staging-tp10c
kubectl get pvc -n staging-tp10c
```

## 3. Despliegue en Producción

```bash
helm upgrade --install notes-production ./devops-portfolio \
  --namespace production-tp10c \
  --create-namespace \
  -f devops-portfolio/values-prod.yaml \
  --wait --timeout 5m --atomic
```

Verificar:

```bash
helm status notes-production -n production-tp10c
kubectl get pods -n production-tp10c
kubectl get deployments -n production-tp10c
kubectl get hpa -n production-tp10c
kubectl get pvc -n production-tp10c
```

## 4. Smoke tests

Verificar el estado de los componentes:

```bash
kubectl rollout status deployment/backend -n staging-tp10c
kubectl rollout status deployment/frontend -n staging-tp10c
kubectl rollout status deployment/postgres -n staging-tp10c
```

Para comprobar el backend mediante port-forward:

```bash
kubectl port-forward svc/backend-service 5000:5000 \
  -n staging-tp10c
```

En otra terminal:

```bash
curl -i http://localhost:5000/health
```

La respuesta esperada es HTTP 200 OK.

## 5. Verificación integral de entornos

Ejecutar:

```bash
./scripts/verificar-helm-entornos.sh
```

El script comprueba:

- Estado de los releases Helm.
- Estado de los Deployments.
- Disponibilidad de los Pods.
- Estado Bound de los PVC.
- Existencia del HPA en Producción.

## 6. Rollback

Consultar el historial:

```bash
helm history notes-production -n production-tp10c
```

Realizar rollback a una revisión anterior:

```bash
helm rollback notes-production REVISION \
  -n production-tp10c --wait
```

Reemplazar `REVISION` por el número de revisión al que se desea regresar.

El workflow también contempla rollback ante fallos en los smoke tests de Producción.

## 7. GitHub Actions

El workflow `helm-cd.yml` implementa:

- Validación Helm para ambos entornos.
- Renderizado de manifiestos.
- Validación YAML.
- Despliegue manual de Staging.
- Despliegue de Producción.
- Aprobación mediante GitHub Environment.
- Smoke tests.
- Rollback ante fallos.

### Configuración requerida

Para ejecutar los despliegues desde GitHub Actions se necesita:

1. Configurar un runner self-hosted en el equipo que tiene acceso al clúster Kind.
2. Asignarle las etiquetas `self-hosted`, `linux`, `x64` y `kind-tp10c`.
3. Configurar el Environment `production` en GitHub.
4. Establecer los revisores requeridos para la aprobación manual.

Los jobs de validación utilizan GitHub-hosted runners. Los jobs de despliegue necesitan el runner self-hosted.

## 8. Estado de las validaciones

Resultado de las verificaciones locales:

| Prueba | Resultado |
|---|---|
| Helm lint Staging | OK |
| Helm lint Producción | OK |
| Render Staging | OK |
| Render Producción | OK |
| YAML Staging | 11 recursos OK |
| YAML Producción | 12 recursos OK |
| Kubernetes dry-run Staging | OK |
| Kubernetes dry-run Producción | OK |
| Despliegue Staging | OK |
| Despliegue Producción | OK |
| PVC Staging | Bound |
| PVC Producción | Bound |
| HPA Producción | Creado |
| Verificación integral | OK |

**Observación:** el HPA de Producción fue creado correctamente. Para obtener métricas de CPU y permitir el escalado automático efectivo se requiere Metrics Server operativo en el clúster.

## Conclusión

Se implementó una estrategia de despliegue multi-entorno utilizando Helm y Kubernetes, con validación previa, separación entre Staging y Producción, verificación de recursos, smoke tests y mecanismos de rollback.

Los despliegues locales de ambos entornos y las validaciones de manifiestos finalizaron correctamente.
