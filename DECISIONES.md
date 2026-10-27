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
- Al cierre de v1, el alcance correspondía a la fase 1. La implementación de mantenimiento se documenta en la sección 6.

## 5. Endpoints de funcionalidad

| Método | Ruta | Función | Acceso |
|---|---|---|---|
| POST | `/api/v1/quotes` | Recibir correo, CP de origen, CP de destino y peso; guardar la solicitud y devolver el resultado de la cotización. | Público |
| GET | `/api/v1/admin/leads?page=1` | Consultar contactos agrupados por correo con sus cotizaciones, en páginas de 50 contactos. | Basic Auth |
| GET | `/api/v1/admin/quotes/:id` | Consultar una cotización guardada con su correo, opciones históricas y datos usados en el cálculo. | Basic Auth |
| GET | `/api/v1/admin/imports` | Consultar los resúmenes de las últimas 20 importaciones. | Basic Auth |
| GET | `/api/v1/admin/imports/:id` | Consultar una importación con sus filas originales, valores normalizados y motivos de aceptación o rechazo. | Basic Auth |

## 6. Fase 2 — requisitos, escenarios y decisiones

Se continúa sobre v1, con las cuatro tablas existentes. La única migración adicional agrega reglas de cobro a paqueterías y dimensiones, origen, referencia externa y vencimiento a cotizaciones. No modifica las opciones ni los precios guardados.

| Requisito / escenario | Decisión implementada |
|---|---|
| Nuevas tarifas DHL desde el primer día del mes siguiente al 20/11/2026. | Fecha efectiva: 01/12/2026, tomada del CSV. Se cargan 24 tarifas nuevas y se cierra la vigencia de las anteriores en esa fecha, sin borrarlas. Las demás paqueterías conservan sus tarifas. |
| El próximo cambio no debe requerir modificar código. | Cada revisión CSV reemplaza el tarifario completo de una paquetería desde una fecha. Se carga con rates:revise[path], en orden cronológico. No se mezclan paqueterías o fechas en un lote. La revisión completa se cancela si alguna fila es inválida; se conserva el tarifario anterior y un reporte del fallo. Repetir un archivo completado no lo duplica. |
| DHL y FedEx usarán volumétrico desde diciembre; Estafeta después, sin fecha. | Reglas con fecha, método y divisor en reglas_cobro.json, cargadas a PostgreSQL. Antes de una regla volumétrica se cobra peso real. Es posible programar Estafeta o cambiar el divisor editando configuración y cargándola, sin cambiar el cálculo. |
| El peso real y el volumétrico caen en rangos distintos. | Calcular por paquetería el mayor entre peso real y largo × ancho × alto / divisor. Redondear el volumétrico hacia arriba al siguiente gramo; conservar el rango (mínimo, máximo]. Mostrar y guardar peso aplicado, método, divisor y precio. |
| No se proporcionan dimensiones. | Permitir las opciones por peso real. Omitir las que exigen volumétrico e indicar qué medidas faltan; nunca aplicarles peso real como sustituto. Si no quedan opciones y faltan medidas, devolver un resultado específico. |
| Solo se captura una medida, una negativa o demasiados decimales. | Validar las tres medidas como conjunto, positivas, menores de 1,000,000 cm y con hasta tres decimales, tanto en formulario como en Rails. No consultar el servicio postal si la entrada es inválida. |
| Respetar lo cotizado durante 30 días. | Leer siempre los importes de las opciones guardadas. Para web: vencimiento exclusivo a los 30 días de quoted_at; la migración lo completa en registros existentes sin tocar precios. Expirar no elimina ni recalcula el historial. El panel distingue vigente, vencida y fecha futura. |
| Registrar 40 cotizaciones dadas por teléfono. | Importar identificador, fecha, correo, ruta, zona, peso y precio originales; fuente manual y referencia externa única. No exigir que el precio exista en las tarifas actuales ni reconstruirlo mediante Zippopotam. Dimensiones, distancia, tarifa de origen, peso facturado y plazo desconocidos permanecen sin informar. |
| El histórico solo informa fecha, sin hora. | Interpretarla en Monterrey y respetar el precio hasta finalizar el día fecha + 30 días. Es un supuesto explícito por falta de hora. Conservar las fechas recibidas aunque algunas sean futuras respecto del reloj real; no cambiar el reloj de la aplicación. |
| Reimportar un histórico con precios diferentes para el mismo identificador. | Rechazar esos registros y conservar el precio previamente guardado. El reporte mantiene originales, normalizados, motivos y procedencia. |
| Growth solicita números diarios, si cabe en el tiempo. | Incluido: total y solicitudes terminadas sin opciones por fecha de Monterrey, separados entre web y manual. Los pendientes cuentan en total, pero no como solicitudes terminadas sin opciones. Los errores y resultados sin tarifa sí cuentan. |

Las revisiones usan las mismas validaciones de peso, precio, zona y plazo de la fase 1. El CSV nuevo tiene encabezados explícitos en kg y MXN; no necesita inferir unidades. Los dos CSV adicionales se copian sin alterar sus bytes a backend/db/data para permitir el arranque desde un clon.

La configuración de cobro del archivo es la fuente del arranque: modificarla y reconstruir el backend para conservar el cambio en reinicios. La tarea rates:rules[path] permite cargarla manualmente; editar únicamente la base no sustituye actualizar el archivo.

### Investigación de Customer Care

- **CP con espacios exteriores:** fase 1 ya aplicaba trim en Vue y Rails. La prueba de regresión con “06600 ” confirma que se consulta “06600” y se cotiza; no se reprodujo el bloqueo descrito.
- **Ciudad en lugar del CP:** el servicio espera cinco dígitos, no geocodifica ciudades. El formulario ahora lo explica expresamente y rechaza la entrada antes de enviarla. La API también la rechaza antes de consultar Zippopotam.
- **Distintas paqueterías con el mismo CP:** compartir un CP no implica compartir destino, peso, fecha y dimensiones. Las opciones dependen de todos esos datos y de tarifas vigentes. Las pruebas confirman resultados iguales con entradas y coordenadas iguales; no hay evidencia suficiente para atribuir el reporte a un fallo del cálculo.
- **Orden de lugares del proveedor:** el promedio ordenado de coordenadas no cambia al reordenar los mismos lugares; se añadió una prueba. Si el proveedor cambia sus coordenadas, la distancia puede variar entre solicitudes; se conservan las coordenadas usadas en cada cotización.

### API y entrega de fase 2

- POST /api/v1/quotes admite length_cm, width_cm y height_cm opcionales como conjunto. Devuelve también vencimiento, peso aplicado y avisos por dimensiones faltantes. La fecha de cálculo la decide el servidor, no el cliente.
- GET /api/v1/admin/stats requiere Basic Auth y devuelve fecha, origen, total y cantidad sin opciones. Limita la respuesta a las últimas 60 combinaciones fecha/origen con actividad.
- Los endpoints existentes mantienen su función y los históricos se consultan desde el mismo panel.
- Las pruebas cubren regresión de v1, cambio de fecha, siguiente revisión por CSV, cancelación atómica, volumétrico, dimensiones, 30 días, 40 históricos, CP y estadísticas. Las respuestas postales se simulan.
- El enunciado sitúa el caso en noviembre y la entrega en octubre. Se respetan las fechas comerciales explícitas de diciembre; las pruebas simulan esas fechas sin alterar el reloj de producción.
