Practica de Integracion y Despliegue Continuo (CI/CD) y Orquestacion con Kubernetes
Autores: Daniel Pacheco, Angélica Panama
Materia: Sistemas Distribuidos
Proyecto: Inventario-App

Este repositorio contiene la implementacion arquitectonica de un pipeline automatizado de CI/CD utilizando GitHub Actions, la contenerizacion de una API en Node.js y su orquestacion local a traves de Minikube.

El diseño del sistema integra practicas de DevSecOps, manejo de configuracion inyectada y estrategias de despliegue con cero tiempo de inactividad (zero-downtime).

Especificaciones Tecnicas y Componentes Adicionales
Analisis de Seguridad Estatico (DevSecOps): Se integro Trivy en el pipeline (.github/workflows/ci-cd.yml) con una politica de "fail-fast" ante vulnerabilidades criticas, mitigando falsos positivos mediante un archivo .trivyignore controlado.

Gestion de Secretos: La aplicacion no expone credenciales en el codigo fuente. Consume una API_KEY que es inyectada dinamicamente en el claster de Kubernetes a traves de variables de entorno montadas desde un recurso Secret.

Control de Ciclo de Vida del Pod (Probes): El backend incluye una simulacion de arranque lento de 20 segundos. Esto es gestionado exitosamente por Kubernetes mediante la configuracion precisa de readinessProbe y livenessProbe, garantizando que el balanceador de carga no envie trafico a contenedores inmaduros.

Guia de Reproduccion y Verificacion
Los siguientes pasos estan disenados para que cualquier evaluador pueda clonar, desplegar y auditar el comportamiento del sistema en un entorno local. Se requiere tener Docker Desktop y Minikube en ejecucion.

Fase 1: Inicializacion del Entorno y Credenciales
Antes de aplicar cualquier manifiesto de despliegue, es mandatorio inicializar el claster y crear el secreto que la aplicacion espera consumir en su arranque.
minikube start
kubectl create secret generic app-secrets --from-literal=API_KEY=12345XYZ


Fase 2: Despliegue Base y Evaluacion de Probes
En esta fase se despliega la aplicacion y se expone a traves de un servicio NodePort.
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
Auditoria del Arranque Lento:
Para evidenciar el correcto funcionamiento del readinessProbe, ejecute inmediatamente el siguiente comando. Observara que los pods permanecen en estado 0/1 (no listos para recibir trafico) durante aproximadamente 20 segundos hasta que la aplicacion supera su carga inicial. Presione Ctrl + C para finalizar la observacion.
kubectl get pods -w


Fase 3: Demostracion de Almacenamiento Efimero (Volatilidad)
Esta prueba evidencia que el almacenamiento por defecto de los contenedores es efimero, justificando la necesidad de Volamenes Persistentes (PV) en arquitecturas reales.

Exponga el servicio hacia el host local para abrir la interfaz web:
minikube service inventario-service
A traves de la interfaz web, registre un nuevo producto en el inventario.

Desde la terminal, identifique y elimine el pod especifico que esta procesando la peticion para forzar la recreacion del contenedor:
kubectl get pods
kubectl delete pod <nombre-del-pod-listado>
Al recargar la interfaz web, el sistema habra perdido el producto registrado, demostrando la volatilidad del almacenamiento local del contenedor destruido.

Fase 4: Estrategia de Despliegue Blue-Green
Esta fase demuestra como realizar actualizaciones de version en produccion aislando el trafico y logrando cero tiempo de inactividad, manipulando unicamente la capa de red (Service).

Paso A: Despliegue de Entornos Paralelos
Levante ambas versiones de la aplicacion (Blue y Green) simultaneamente en el claster. Ninguna interfiere con la otra.
kubectl apply -f k8s/blue-green/deployment-blue.yaml
kubectl apply -f k8s/blue-green/deployment-green.yaml

Paso B: Enrutamiento a la Version Estable (Blue)
Verifique que el archivo k8s/service.yaml posea la directiva version: blue en su selector y apliquelo para enrutar todo el trafico a la version actual.
kubectl apply -f k8s/service.yaml
Acceda a la ruta /version en el navegador; la respuesta JSON confirmara el entorno indicando "color": "blue".

Paso C: Intercambio de Trafico Instantaneo (Cut-over a Green)
Para promover la nueva version a produccion, edite el archivo k8s/service.yaml modificando el selector a version: green. Aplique el cambio:
kubectl apply -f k8s/service.yaml
Al recargar la ruta /version en el navegador, la respuesta cambiara inmediatamente a "color": "green". El trafico ha sido redirigido a nivel de balanceador de carga sin requerir el reinicio de los contenedores ni causar perdida de paquetes.
