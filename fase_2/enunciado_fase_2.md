# Fase 2 — Mantenimiento

*(Trabájala después de cerrar la fase 1 con el tag `v1`. Construye sobre lo que ya hiciste; no empieces de cero.)*

Hoy es viernes 20 de noviembre de 2026. Han pasado tres semanas. El cotizador está en producción y se usó en la campaña. Llegaron estos mensajes el mismo día.

### Correo de Comercial

> **De:** Héctor, Comercial
> **Asunto:** Cambio de tarifas DHL + volumétrico
>
> Equipo, dos cosas:
>
> 1. DHL nos mandó tarifas nuevas, aplican **a partir del 1 del próximo mes** (adjunto `datos/tarifas_dhl_v2.csv`). Las demás paqueterías siguen igual.
> 2. Desde esa misma fecha, DHL y FedEx cobran por **peso volumétrico**: se toma el mayor entre el peso real y (largo × ancho × alto en cm) / 5000. Estafeta, por ahora, sigue cobrando por peso real; nos avisó que también lo aplicará cuando renovemos su contrato, todavía sin fecha.
>
> Importante: **las cotizaciones que ya le dimos a la gente se respetan durante 30 días**. Si alguien cotizó y nos llama dentro de ese plazo, se le cobra lo que vio en pantalla, aunque la tarifa haya cambiado. Adjunto `datos/cotizaciones_historicas.csv` con 40 cotizaciones que Comercial dio por teléfono, fuera del cotizador, y que también deben quedar registradas en el sistema.
>
> Héctor

### Mensaje de Customer Care (Slack)

> hola, el cotizador se traba a veces cuando pones el CP con espacios o cuando escribes la ciudad. una clienta nos dijo que puso "06600 " y no le salió nada. también varios nos preguntan por qué les sale una paquetería y a su vecino otra con el mismo CP. ¿es normal?
>
> — Mariana

### Comentario de Growth

> Ahora que tenemos leads, ¿podemos saber cuántas cotizaciones por día y cuántas terminan sin ninguna opción? Un número en la vista interna nos basta.
>
> — Daniela

### Lo que esperamos

- Que la fase 1 siga funcionando. Las cotizaciones ya guardadas no deben cambiar de precio.
- Que el cambio de tarifas y la regla de volumétrico queden implementados de forma que el **próximo** cambio de tarifas no requiera tocar código.
- Que investigues los reportes de Customer Care y nos digas qué encontraste, aunque la respuesta sea "no es un bug".
- Lo que pide Growth, si cabe en el tiempo. Si no cabe, dilo en la entrega.
- Pruebas para lo nuevo, migraciones de base de datos para lo que cambie, `ENTREGA_FASE_2.md`, y actualizar `DECISIONES.md`.

Tag `v2` al terminar, a más tardar el martes 27 de octubre de 2026 a las 15:00, hora de Monterrey.
