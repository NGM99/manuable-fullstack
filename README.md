# Manuable — cotizador

Fase 1: Rails API, PostgreSQL 17 y Vue 3 con TypeScript, Vite y Tailwind. Ruby sustituye a Python según la autorización comunicada por el candidato.

## Ejecutar

Solo requiere Docker con Compose y contenedores Linux; las imágenes base tienen variantes AMD64 y ARM64. No requiere instalar Ruby, Node ni PostgreSQL.

    docker compose up --build

- Cotizador: http://localhost:5173
- Comercial: http://localhost:5173/admin
- Acceso local: usuario comercial, contraseña manuable_local_only.
- API y salud: http://localhost:3000/api/v1/health

El arranque crea la base, aplica la migración e importa automáticamente los CSV incluidos en backend/db/data. Repetirlo no duplica la carga. Los datos persisten en el volumen de PostgreSQL.

Las credenciales y puertos se pueden configurar con las variables de .env.example. En Windows, usar WATCH_USE_POLLING=true en .env si Vite no detecta cambios. El frontend tiene recarga automática; para cambios del backend repetir el comando de arranque.

## Uso

Capturar CP de origen, CP de destino, peso positivo en kg y correo. Ejemplo: 06600 → 06600, 2.5 kg. Requiere conexión a Zippopotam; las opciones dependen de las tarifas disponibles.

Comercial puede consultar los contactos con su historial y los reportes de importación, incluyendo cada fila original, valores normalizados y motivos de aceptación o rechazo. Las credenciales permanecen en memoria del navegador.

## API

| Método | Ruta | Acceso |
|---|---|---|
| POST | /api/v1/quotes | Público; JSON con email, origin_postal_code, destination_postal_code, weight_kg |
| GET | /api/v1/admin/leads?page=1 | Basic Auth; contactos con cotizaciones |
| GET | /api/v1/admin/quotes/:id | Basic Auth; cotización guardada |
| GET | /api/v1/admin/imports y /api/v1/admin/imports/:id | Basic Auth; resumen y auditoría |

CP no localizado devuelve 422; servicio postal no disponible, 503. Ambos conservan la solicitud válida y su correo. Sin tarifas se devuelve una cotización sin opciones y un mensaje claro. Los datos mal formados devuelven 422 sin consultar el servicio externo.

## Datos y alcance

Solo cuatro tablas: carriers, rates, rate_imports y quotes. El correo va en la cotización; las opciones históricas y la auditoría de las cargas se guardan como JSONB.

Se importan cuatro paqueterías y 25 tarifas de 108 filas; 83 quedan rechazadas con motivos. No se infieren unidades, fechas ni precios ausentes. revision_pendiente.json identifica filas con precios atípicos o conflicto comercial que requieren confirmación. Los originales se incluyen sin alterar sus bytes.

La distancia usa coordenadas de Zippopotam y Haversine; zonas hasta 100, 500 y 1,000 km, y mayores. Rangos de peso: mínimo exclusivo y máximo inclusivo. Los precios son MXN. Cobertura real, impuestos y plazos requieren confirmación comercial; no existe un catálogo de cobertura por CP.

Para repetir la carga manualmente:

    docker compose exec backend bundle exec rails rates:import

## Verificación

    docker compose --profile test run --build --rm tests

Ejecuta RSpec, Vitest, verificación de carga Rails, TypeScript y compilación Vue. Usa PostgreSQL de pruebas independiente, red interna y respuestas postales simuladas; no necesita servicios externos durante las pruebas. La construcción inicial sí descarga dependencias.

Para ejecutar únicamente las pruebas del backend:

    docker compose --profile test run --build --rm --entrypoint sh tests -lc 'bundle exec rails db:prepare && bundle exec rspec'

RSpec comprueba importación y auditoría CSV, límites de zona y peso, captura del contacto, conservación del precio histórico, autenticación y respuestas ante CP inexistentes o fallos del servicio postal. La integración HTTP se simula con RSpec Mocks: también se verifican JSON inválido, coordenadas inválidas y tiempos de espera sin llamar a Zippopotam.

Últimas verificaciones: 22 pruebas RSpec y 7 pruebas Vitest aprobadas; TypeScript y compilación Vue correctos. El frontend utiliza Axios para las peticiones a Rails.

Entorno de desarrollo local. Apple Silicon no se verificó físicamente. La fase 1 queda cerrada con el tag v1; la fase 2 está pendiente y se implementará sobre esta versión.
