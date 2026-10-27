# Decisiones — fase 1

Este documento resume los escenarios identificados al revisar el requerimiento y los archivos recibidos, las decisiones tomadas y lo implementado. Las condiciones comerciales sin confirmar siguen siendo supuestos, no respuestas del área.

## 1. Escenarios identificados en los requisitos

| Escenario o duda inicial | Decisión y comportamiento implementado |
|---|---|
| Growth necesita el correo de quien cotiza y Comercial debe consultar sus solicitudes. | Correo obligatorio; cada solicitud válida se guarda como cotización. El panel agrupa las cotizaciones por correo normalizado, sin crear una tabla adicional de contactos. |
| Una persona puede cotizar varias veces. | Se conserva cada intento con su fecha, ruta, peso, resultado y opciones mostradas. No se reemplaza su cotización anterior. |
| Comercial define zonas aproximadas por distancia, sin indicar cómo medirla. | Se usa Haversine entre coordenadas de Zippopotam: zona 1 hasta 100 km, zona 2 hasta 500, zona 3 hasta 1,000 y zona 4 para distancias mayores. Los límites superiores son inclusivos. |
| Un CP puede devolver varios lugares. | Se promedian sus coordenadas válidas. Si origen y destino coinciden, se consulta ese CP una sola vez. Se guardan las coordenadas usadas y la distancia. |
| Zippopotam no encuentra el CP o no responde. | Se muestra un mensaje específico, con límites de espera, y se conserva la solicitud válida con su correo. No se inventan coordenadas ni tarifas. |
| Existe una zona, pero no una tarifa confiable para el peso solicitado. | Se devuelve una cotización sin opciones y un mensaje claro. No se extrapolan ni interpolan precios. |
| El peso coincide con el límite entre dos rangos. | Se usa mínimo exclusivo y máximo inclusivo: mínimo < peso ≤ máximo. Se aceptan pesos positivos con hasta tres decimales en kg. |
| No se proporcionó un catálogo de cobertura por CP. | Las opciones son estimaciones según zona y peso; no se garantiza cobertura real. Debe confirmarse con Comercial antes de contratar. |
| La vista de Comercial no debe ser pública. | API interna protegida con Basic Auth y credenciales configurables. El navegador conserva las credenciales solo en memoria. El entorno entregado es local; publicarlo requiere HTTPS. |
| Las tarifas pueden cambiar después de una cotización. | Se guarda una copia de las opciones mostradas, incluidos precio, paquetería y plazo. Consultar el historial no recalcula los importes con las tarifas actuales. |

## 2. Reglas de normalización por CSV

Los originales se conservan sin modificar en backend/db/data. Primero se importa paqueterias.csv y después tarifas.csv, porque las tarifas necesitan relacionarse con el catálogo.

### 2.1. paqueterias.csv — catálogo de paqueterías

Columnas obligatorias: carrier_id, nombre, tipo_servicio y activo.

| Campo o situación | Regla aplicada |
|---|---|
| carrier_id | Quitar espacios al inicio y al final; exigir un valor presente y único. Sirve para crear o actualizar la misma paquetería por su identificador externo. |
| nombre | Quitar espacios al inicio y al final y exigir que no esté vacío. Se conserva el nombre del catálogo; las equivalencias de nombres se resuelven al importar tarifas. |
| tipo_servicio | Ignorar mayúsculas y espacios sobrantes al comparar. Convertir aéreo → air y terrestre → ground. Rechazar valores desconocidos. |
| activo | Ignorar mayúsculas y espacios sobrantes al comparar. Convertir si o sí → true y no → false. Rechazar vacíos y valores desconocidos. |
| Paquetería inactiva | Conservarla en el catálogo. Redpack queda registrada con activo=false; esto impide publicar sus tarifas. |

Resultado del archivo recibido: cuatro paqueterías normalizadas, tres activas y una inactiva; ninguna fila rechazada.

### 2.2. tarifas.csv — precios y condiciones

Columnas obligatorias: paqueteria, zona, peso_min, peso_max, unidad, precio, dias_entrega y vigencia_desde. Que una columna exista no significa que pueda dejarse vacía.

| Campo o situación | Regla aplicada |
|---|---|
| paqueteria | Quitar espacios exteriores, reducir espacios repetidos e ignorar mayúsculas para buscar en el catálogo. Equivalencias explícitas: DHL Express y D.H.L. → DHL; Estafeta Mexicana → Estafeta; Fed Ex y Federal Express → FedEx; Red Pack → Redpack. Rechazar desconocidas, como Paquetería Rayo, e inactivas, como Redpack. |
| zona | Convertir variantes como Z1, ZONA 1 y zona1 al entero 1. Admitir únicamente 1, 2, 3 y 4; rechazar Zona 7, vacíos y formatos no reconocidos. |
| unidad | Quitar espacios exteriores e ignorar mayúsculas. Admitir solo g y kg. Convertir gramos a kg dividiendo ambos pesos entre 1,000. Rechazar unidad faltante o desconocida sin inferirla por el tamaño del número. |
| peso_min y peso_max | Admitir números con punto decimal; exigir mínimo ≥ 0 y máximo > mínimo. Después de convertir a kg, admitir hasta tres decimales y valores menores de 1,000,000,000 kg. Rechazar vacíos, rangos inválidos o precisión superior a un gramo. |
| precio | Quitar espacios exteriores, símbolo $ inicial y sufijo MXN. Normalizar formatos inequívocos: $1,137.24 → 1137.24 y 311,04 → 311.04. Guardar como decimal en MXN, positivo, con hasta dos decimales y menor de 10,000,000,000. Rechazar vacíos, cero, negativos o formatos ambiguos. |
| Precios atípicos | Excluir las seis filas identificadas en revision_pendiente.json hasta confirmación comercial. No dividir importes por 100 ni sustituirlos por promedios. La lista corresponde a la revisión de estos datos; no es un detector automático para archivos futuros. |
| vigencia_desde | Convertir fechas reconocidas e inequívocas a ISO: 2026-01-01, 01/01/2026 y 1-ene-2026 → 2026-01-01. Rechazar vacíos, fechas inválidas o ambiguas, como 03/04/2026. No usar la fecha de carga como sustituto. Las tarifas futuras pueden guardarse, pero solo se cotizan cuando están vigentes. |
| dias_entrega | Convertir 3 o 3 días a mínimo=3 y máximo=3; 1-3 a mínimo=1 y máximo=3. Exigir enteros positivos y máximo ≥ mínimo. Si falta, guardar ambos límites nulos y mostrar “Plazo por confirmar”; no rechazar únicamente por esa ausencia. No asumir días hábiles o naturales. |
| Duplicados | Rechazar filas originales repetidas y tarifas con la misma paquetería, zona, rango de peso y fecha inicial ya registrados. No publicar dos veces la misma tarifa. |
| Rangos superpuestos | Rechazar conflictos de peso y vigencia con tarifas ya registradas para la misma paquetería y zona. Además, excluir expresamente la fila DHL de 3–6 kg indicada en revision_pendiente.json hasta aclaración comercial. |

Resultado del archivo recibido: 108 filas revisadas, 25 normalizadas y publicadas, 83 rechazadas. Una fila puede incumplir varias reglas; las filas señaladas para revisión también pueden tener otros motivos de rechazo.

### 2.3. Reglas comunes de importación

- Leer CSV con encabezados en UTF-8, admitiendo BOM. Rechazar filas con un número incorrecto de columnas; registrar como fallida la carga si faltan encabezados obligatorios o el CSV está mal formado.
- Detectar filas originales repetidas dentro de cada archivo y rechazar las repeticiones posteriores.
- No modificar los originales ni completar datos por suposición. Guardar los campos originales y los valores normalizados con los motivos de cada fila.
- Clasificar cada fila como ACEPTADO, NORMALIZADO o RECHAZADO. Solo las filas sin errores se guardan en las tablas comerciales.
- Identificar cada carga por archivo, SHA-256 y versión de reglas. Reutilizar una carga completada idéntica para evitar duplicarla.

## 3. Resultado y trazabilidad de la carga

- Catálogo: cuatro paqueterías normalizadas; tres activas y una inactiva.
- Tarifas: 108 filas revisadas, 25 normalizadas y publicadas, 83 rechazadas. Una fila puede tener varios motivos de rechazo.
- Cada importación guarda archivo, SHA-256, versión de reglas, fecha, estado y contadores. Cada fila conserva número de línea, campos originales, valores normalizados, clasificación y motivos.
- Comercial puede consultar el resumen y el detalle desde el panel interno.
- Repetir el mismo archivo con la misma versión de reglas reutiliza la importación completada y no duplica las tarifas. No se implementó una pantalla de edición de los datos rechazados.

## 4. Implementación y alcance

- Ruby/Rails sustituye a Python según la autorización comunicada por el candidato.
- Se simplificó a cuatro tablas: carriers, rates, rate_imports y quotes. Las filas auditadas y las opciones históricas se guardan como JSONB por el volumen pequeño de esta prueba.
- Docker prepara la base e importa los archivos al arrancar. No se requieren Ruby, Node ni PostgreSQL instalados en el equipo del evaluador.
- Las pruebas críticas usan respuestas postales simuladas para no depender de Zippopotam.
- Cobertura por CP, precios observados, datos faltantes, impuestos y tipo de días requieren confirmación comercial. Los pendientes quedan identificados en este documento y en ENTREGA_FASE_1.md.
- Este cierre corresponde a la fase 1; las reglas de mantenimiento de la fase 2 todavía no se implementaron.

## 5. Endpoints de funcionalidad

| Método | Ruta | Función | Acceso |
|---|---|---|---|
| POST | `/api/v1/quotes` | Recibir correo, CP de origen, CP de destino y peso; guardar la solicitud y devolver el resultado de la cotización. | Público |
| GET | `/api/v1/admin/leads?page=1` | Consultar contactos agrupados por correo con sus cotizaciones, en páginas de 50 contactos. | Basic Auth |
| GET | `/api/v1/admin/quotes/:id` | Consultar una cotización guardada con su correo, opciones históricas y datos usados en el cálculo. | Basic Auth |
| GET | `/api/v1/admin/imports` | Consultar los resúmenes de las últimas 20 importaciones. | Basic Auth |
| GET | `/api/v1/admin/imports/:id` | Consultar una importación con sus filas originales, valores normalizados y motivos de aceptación o rechazo. | Basic Auth |
