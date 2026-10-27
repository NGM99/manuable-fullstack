# Manuable — cotizador

Rails API, Vue 3 con TypeScript y PostgreSQL. Ruby sustituye a Python según la autorización comunicada por el candidato.

## Requisitos

- Git y Docker con Docker Compose v2; en Windows o Mac, Docker Desktop iniciado con contenedores Linux.
- Conexión a internet para descargar imágenes y dependencias, y para consultar códigos postales mediante Zippopotam.
- Puertos 5173 y 3000 disponibles. No necesitas instalar Ruby, Node ni PostgreSQL.

## Levantar el proyecto

Clonar y entrar al repositorio:

    git clone https://github.com/NGM99/manuable-fullstack.git
    cd manuable-fullstack

Ejecutar desde la raíz:

    docker compose up --build -d --wait

El comando levanta PostgreSQL, Rails y Vue, aplica las migraciones y carga automáticamente las paqueterías, tarifas y 40 cotizaciones históricas. La primera construcción puede tardar varios minutos. Repetir el arranque no duplica las cargas.

| Pantalla | Dirección |
|---|---|
| Cotizador público | http://localhost:5173 |
| Acceso Comercial | http://localhost:5173/admin |
| Estado de la API y PostgreSQL | http://localhost:3000/api/v1/health |

**Credenciales locales de Comercial**

- Usuario: comercial
- Contraseña: manuable_local_only

Estos valores aplican si no se personalizaron ADMIN_USER y ADMIN_PASSWORD en .env. No es necesario crear ese archivo para ejecutar el proyecto; .env.example contiene las opciones disponibles.

## Usar la aplicación

En el cotizador, ingresar correo, CP de origen, CP de destino y peso en kg. Ejemplo: 06600 → 06600, 2.5 kg y prueba@example.com. Las opciones dependen de las tarifas y de la disponibilidad del servicio postal.

Agregar largo, ancho y alto en cm para comparar opciones que requieran peso volumétrico. Las nuevas tarifas DHL y el volumétrico para DHL/FedEx se activan el 01/12/2026; no se modifica el reloj de la aplicación.

En Comercial se pueden buscar contactos por correo, consultar cotizaciones y vigencias, ver indicadores diarios y revisar las filas y motivos de cada importación.

## Ejecutar las pruebas

Desde la raíz:

    docker compose --profile test run --build --rm tests

Ejecuta las pruebas de Rails y Vue, TypeScript y compilación del frontend. Usa una base de pruebas separada y respuestas postales simuladas; no modifica los datos de desarrollo ni depende de servicios externos durante las pruebas. La construcción inicial sí requiere internet.

## Detener y consultar el entorno

Detener los servicios conservando los datos:

    docker compose down

Consultar estado y registros:

    docker compose ps
    docker compose logs --tail=100 backend frontend

Para aplicar cambios del código, repetir el comando de arranque. El frontend tiene recarga automática; en Windows, si no detecta cambios, configurar WATCH_USE_POLLING=true en .env y ejecutar de nuevo el arranque.

Las imágenes admiten AMD64 y ARM64. Es un entorno local de evaluación; las credenciales incluidas son exclusivamente de desarrollo. Las decisiones y límites comerciales están en DECISIONES.md y los cierres de cada fase en ENTREGA_FASE_1.md y ENTREGA_FASE_2.md.
