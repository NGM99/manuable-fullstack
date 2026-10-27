# Prueba técnica — Desarrollador Fullstack (Mid)
## Manuable · Equipo de Desarrollo

Gracias por tu interés en Manuable. Somos una plataforma de logística: conectamos tiendas en línea con paqueterías para que generar una guía de envío sea tan fácil como comprar en línea.

Esta prueba **no es una lista de tareas**. Es un requerimiento de negocio escrito por las personas que lo necesitan, con la misma claridad (y los mismos huecos) con los que llegan los requerimientos reales. Evaluamos tanto cómo resuelves como qué decides, qué preguntas y cómo lo comunicas.

Tiene dos fases y las recibes juntas: `fase_1/` y `fase_2/`. La fase 2 es mantenimiento sobre lo que construyas en la fase 1. Resuelve primero la fase 1, ciérrala con el tag `v1` y después trabaja la fase 2 sobre el mismo repositorio.

---

## Reglas del juego

**Stack**
- Backend en **Python 3.12**. Framework libre.
- Frontend en **TypeScript**. Librería libre.
- Base de datos **PostgreSQL 15 o superior** (estrictamente; puede ser una imagen de Docker).
- Integración con una **API pública** indicada más abajo.

**Entorno**
Quien revise tu prueba trabaja en una Mac con Apple Silicon y **solo tiene instalados git, Docker y Nix**. No tiene Python ni Node y no los va a instalar. Debe poder levantar el proyecto completo (base de datos, backend, frontend, datos de ejemplo) con **un solo comando** documentado en el `README.md`, y correr las pruebas automatizadas con otro. Cómo lo logres es parte de la evaluación.

**Comunicación**
- Este es un proyecto con stakeholders. Si el requerimiento no te queda claro, **pregunta**: escribe tus dudas en un archivo `PREGUNTAS.md` en la raíz del repositorio y envíalo en cualquier momento a **developers@manuable.com**; te responderemos como lo haría el área (a más tardar al siguiente día hábil). También puedes decidir por tu cuenta y documentar el supuesto en `DECISIONES.md`. Ambos caminos son válidos; lo que evaluamos es el criterio.
- Al terminar cada fase, además del código, entrega un mensaje de **máximo 150 palabras** dirigido al área que pidió la funcionalidad (no al equipo técnico): qué quedó listo, qué no, qué riesgos ves y qué recomiendas. Va en `ENTREGA_FASE_N.md`.

**Entrega**
- Repositorio Git (público o con acceso para nosotros). Haz commits conforme avances; el historial también cuenta.
- Al cerrar la fase 1, crea el tag `v1`; al cerrar la fase 2, el tag `v2`.
- **Fecha límite para las dos fases: martes 27 de octubre de 2026 a las 15:00, hora de Monterrey.** Te sugerimos dedicar de 2 a 3 días a la fase 1 y 1 día a la fase 2. Revisamos lo que esté en el repositorio a esa hora.
- Si la API pública deja de responder mientras trabajas, avísanos a developers@manuable.com; lo tomaremos en cuenta al revisar.
- No esperamos que todo quede perfecto. Esperamos que lo que no quedó esté identificado y explicado.

**Uso de IA**
Puedes usar asistentes de IA. Te pediremos explicar cualquier parte del código en la entrevista de revisión, así que asegúrate de entender todo lo que entregues.

---

## Fase 1 — El requerimiento

### Correo de Growth

> **De:** Daniela, Growth
> **Para:** Equipo de Desarrollo
> **Asunto:** Cotizador en la landing — urgente para campaña de noviembre
>
> Hola equipo,
>
> Estamos perdiendo leads. La gente llega a la landing desde los anuncios, no sabe si llegamos a su ciudad ni cuánto cuesta, y se va. Queremos un cotizador público: la persona pone código postal de origen, código postal de destino y el peso del paquete, y le mostramos qué paqueterías cubren esa ruta, cuánto cuesta y en cuántos días llega.
>
> Lo importante para nosotros: **que capture el correo** de quien cotiza. Cada cotización se guarda y Comercial le llama después.
>
> Comercial ya nos pasó las tarifas de las paqueterías (adjunto `tarifas.csv` y `paqueterias.csv`). Las tarifas van por **zona** y por **rango de peso**. La zona depende de la distancia entre origen y destino; Comercial dice que es más o menos así: zona 1 hasta 100 km, zona 2 hasta 500, zona 3 hasta 1,000 y zona 4 lo demás.
>
> Lo necesitamos para la campaña de noviembre. ¡Gracias!
>
> Daniela

### Nota de Comercial (en respuesta al hilo)

> Ojo con el archivo de tarifas: lo armamos juntando lo que nos mandó cada paquetería por correo y hojas de cálculo distintas, así que seguramente tiene cosas raras. Si ven algo que no cuadra, díganos. Lo que sí: **no inventen tarifas**, si para un rango no tenemos precio preferimos no cotizarlo.
>
> — Héctor, Comercial

### Comentario de Customer Care

> Lo que sea que hagan, que la persona no se quede sin respuesta. Si no llegamos a su CP o algo falla, que vea un mensaje claro y no una pantalla en blanco. Nos escriben a nosotros cuando eso pasa.
>
> — Mariana, Customer Care

### Lo que te damos

- `datos/paqueterias.csv` — catálogo de paqueterías.
- `datos/tarifas.csv` — tarifas por paquetería, zona y rango de peso, tal como las recibió Comercial.
- Para convertir un código postal en coordenadas puedes usar la API pública **Zippopotam** (`https://api.zippopotam.us/mx/{codigo_postal}`), sin registro ni llave. No cubre todos los códigos postales de México.

### Lo que esperamos como mínimo

1. Un proceso de **carga de tarifas** desde el CSV a PostgreSQL. El CSV viene como viene; parte del trabajo es dejar los datos limpios, consistentes y confiables antes de cotizar con ellos. Queremos poder ver qué se cargó, qué se corrigió y qué se rechazó, y por qué.
2. Un **API** para cotizar y para consultar los leads capturados.
3. Un **formulario público** de cotización y una **vista interna** sencilla donde Comercial vea los leads con sus cotizaciones. La vista interna no debe quedar abierta al público; un mecanismo de acceso simple es suficiente.
4. **Pruebas automatizadas** de lo que consideres crítico. Deben poder correr sin depender de servicios externos.
5. `README.md`, `DECISIONES.md` y `ENTREGA_FASE_1.md`.

No hay más especificación que esta. Lo que falte, pregúntalo o decídelo.
