# Frontend

Vue 3, Composition API, TypeScript, Vite, Tailwind CSS y Vitest

## Desarrollo con recarga automática

Desde la raíz del proyecto, iniciar el entorno completo:

```sh
docker compose up --build
```

`frontend/` se comparte con `/app` mediante un bind mount. Al guardar cambios en Vue, TypeScript o CSS, Vite los detecta y actualiza el navegador. `/app/node_modules` usa un volumen anónimo propio del contenedor para mantener las dependencias Linux separadas del anfitrión.

En Windows con Docker/WSL2, configurar `WATCH_USE_POLLING=true` en el archivo `.env` de la raíz. Compose pasa esa variable al proceso de Vite. El sondeo revisa archivos cada 300 ms. En Mac/Linux el valor por defecto es `false`; activarlo únicamente si no se detectan cambios, porque aumenta el uso de CPU.

Después de cambiar esta variable o los montajes, recrear el frontend del entorno ya iniciado:

```sh
docker compose up -d --no-deps --wait frontend
```

Los cambios habituales de código no requieren reconstrucción. Al cambiar dependencias o el Dockerfile, reconstruir y renovar únicamente el volumen anónimo del frontend:

```sh
docker compose up -d --build --no-deps --renew-anon-volumes --wait frontend
```

Las pruebas conservan su contenedor independiente, sin montar el código local:

```sh
docker compose --profile test run --build --rm tests
```
