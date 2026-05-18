# Estado de pruebas unitarias

> Documento vivo. Cada vez que se agrega un módulo o se descubre deuda de
> testing, actualizar aquí. El objetivo no es tener "tests por tener" sino
> proteger las invariantes críticas que la app ya rompe en sesiones previas.

## Snapshot actual

| Métrica | Valor |
|---------|-------|
| Tests unitarios | **0** |
| Tests de widget | **0** |
| Tests de integración | **0** |
| Coverage | **0%** |

La app fue construida con priorización en feature delivery. No hay
infraestructura de tests aún.

## Módulos críticos sin cobertura

Ordenados por impacto / probabilidad de regresión:

### 🔴 Alto — bugs ya observados en producción

1. **`lib/shared/utils/provider_capabilities.dart`** (`ProviderId.fromDomain`,
   capabilities). Es la base del routing por proveedor. Romperlo = todo el
   app se confunde sobre quién es quién.
2. **`lib/features/player/data/player_provider.dart`** (`_serverScore`,
   `_isNativePlayableUrl`). Bug previo: `mp4upload.com` era detectado como
   archivo `.mp4` por substring match. Ya hay regex pero merece test.
3. **`lib/features/player/presentation/player_screen.dart`**
   `_inferAnimeUrl`. Cada proveedor tiene un patrón distinto; añadir uno
   nuevo mal puede romper el detalle dentro del player.
4. **`lib/features/home/data/home_provider.dart`** `catalogGenreValue`.
   Slug-ifica género (lowercase + sin tildes). Falla en HentaiLA porque ese
   sitio espera el label tal cual — ya hay tests anecdóticos pero ninguno
   automatizado.

### 🟡 Medio — invariantes de negocio

5. **`lib/features/watchlist/data/watchlist_provider.dart`**
   `autoUpdateFromPlayback`. Reglas: "Viendo" en primer episodio, "Completado"
   en último, no tocar manuales. Es lógica que crece y merece tests.
6. **`lib/features/favorites/data/favorites_provider.dart`** toggle y filtro
   por proveedor. La persistencia en SharedPreferences tiene serialización
   custom que podría romper.
7. **`lib/features/schedule/presentation/schedule_screen.dart`**
   `_weekStrip`, `_isPast`, `_sortByTime`. Helpers de fecha que son fáciles
   de testear y propensos a off-by-one.

### 🟢 Bajo — UI o capas con poco riesgo

8. Widgets compuestos (`_DayChip`, `_MonosTimelineRow`, `_GenrePill`). Test
   solo si cambian su contrato de API; visualmente se validan en device.

## Plan mínimo viable (MVP de cobertura)

Si se decide arrancar con tests, esta es la lista de archivos a crear,
ordenada por ratio impacto/esfuerzo:

```
test/
├── shared/utils/
│   └── provider_capabilities_test.dart       # 8-10 cases (fromDomain, capabilities)
├── features/player/
│   └── inference_test.dart                   # _inferAnimeUrl x cada proveedor
│   └── native_url_test.dart                  # _isNativePlayableUrl true/false matrix
├── features/home/
│   └── catalog_genre_value_test.dart         # tildes, ñ, espacios → slugs
└── features/watchlist/
    └── auto_update_test.dart                 # transiciones de estado
```

Estimación: 1 sesión de ~3 horas cubre los **🔴 altos** completos, con
suficientes casos límite para detectar regresiones reales.

## Decisiones pendientes

- ¿Se adopta `mocktail` o `mockito` para mocks de Dio/SharedPreferences? El
  ecosistema Flutter va más hacia `mocktail`. Decidir antes del primer test
  que requiera mocks de IO.
- ¿Se mide cobertura con `flutter test --coverage` y se publica en algún
  badge / acción de CI? Hoy no hay CI; agregarlo es prerequisito para que la
  cobertura sea visible.
- ¿Se acepta dejar tests de integración fuera del scope inicial? Sí — el
  costo/beneficio de tests E2E sin pipeline es bajo. Foco en unit primero.

## Bitácora

| Fecha | Cambio |
|-------|--------|
| 2026-05-17 | Documento creado. Cobertura: 0. Sin tests escritos. |
