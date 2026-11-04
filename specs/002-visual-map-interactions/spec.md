# Feature Specification: Visualización 2.5D del Terreno e Interacciones Expresivas de los Habitantes

**Feature Branch**: `002-visual-map-interactions`

**Created**: 2026-11-04

**Status**: Approved

**Input**: User description: "Mejorar cómo se visualiza el terreno de juego (actualmente una rejilla hexagonal 2D plana) mediante relieve 2.5D por altitud, ilustración de biomas e indicadores integrados de recursos y degradación ecológica, y hacer que se entiendan mejor las interacciones y el estado de los habitantes mediante iconos de acción dominante en cada Deme, anillos de estado vital y cultura, arcos animados directos Deme-a-Deme (intra-hexágono e inter-hexágono) y controles de zoom y paneo en el mapa."

## Clarifications

### Session 2026-11-04

- Q: ¿Qué enfoque visual debe emplearse para evolucionar el terreno hexagonal? → A: Vista 2.5D con relieve topográfico por altitud, iconografía/ilustración vectorial distintiva por bioma, diferenciación de costas/océano y ambiente estacional, manteniendo claridad visual y simplicidad arquitectónica.
- Q: ¿Cómo deben representarse las acciones, el estado y las interacciones de los habitantes (*demes*) sobre el tablero? → A: Mediante tres mejoras combinadas: (1) insignia/icono de la acción dominante del turno en cada *deme* (recolectar, sobreexplotar, migrar, cooperar, comerciar, disputar, innovar), (2) anillo de estado vital (prosperando, estable, en dificultades, en hambruna) e indicador de posesión de cultura, y (3) arcos animados directos *deme-a-deme* que conecten las poblaciones que migran, comercian o disputan, incluso dentro del mismo hexágono.
- Q: ¿Qué capacidades de navegación e información ambiental deben integrarse directamente en el mapa? → A: Controles de acercamiento y desplazamiento (*Pan & Zoom*) para inspeccionar hexágonos poblados de cerca, e indicadores visuales integrados de abundancia de recursos y degradación del hábitat directamente sobre el terreno sin obligar al usuario a cambiar de lente.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Terreno Hexagonal 2.5D con Biomas Ilustrados e Indicadores Ecológicos Integrados (Priority: P1)

Como observador naturalista, quiero que el mapa hexagonal represente visualmente la elevación topográfica de cada celda, motivos gráficos distintivos de su bioma (bosque tropical, sabana, estepa árida, tundra, alta montaña, aguas costeras y océano) e indicadores visuales integrados de abundancia de alimento y degradación ecológica en la vista principal, para identificar de un vistazo la geografía física, las barreras montañosas o marítimas y el estado de conservación de cada hábitat sin tener que cambiar constantemente entre lentes del mapa.

**Why this priority**: El terreno es la base espacial sobre la que ocurren todas las decisiones y dinámicas ecológicas; si los biomas, altitudes y recursos solo se distinguen por colores planos o cambiando de lente, el jugador pierde el contexto ambiental que explica las decisiones de los habitantes.

**Independent Test**: Puede probarse cargando cualquiera de los escenarios preconfigurados en la lente principal de biomas y verificando visualmente que (a) las celdas presentan relieve proporcional a su altitud, (b) cada uno de los 7 tipos de bioma muestra una ilustración o motivo topográfico propio además de su paleta cromática, y (c) cada celda terrestre muestra indicadores visuales directos de su nivel actual de recursos y de deterioro de su capacidad de carga ($K / K_{\max}$) cuando sufre sobreexplotación.

**Acceptance Scenarios**:

1. **Given** un escenario cargado en la vista del mapa, **When** el usuario observa celdas con distinta altitud (desde costas bajas hasta alta montaña), **Then** cada celda muestra un espesor/relieve 2.5D y sombreado proporcional a su valor de altitud y distingue visualmente las celdas sumergidas de las terrestres.
2. **Given** la lente principal de biomas activa, **When** el usuario observa el tablero, **Then** cada celda presenta motivos gráficos representativos de su bioma (vegetación densa en bosque tropical, acacias/hierba en sabana, dunas/matorral en estepa, relieve escarpado en alta montaña, cristales/hielo en tundra, ondas en océano y bajíos costeros).
3. **Given** una celda terrestre habitada cuya capacidad de carga ($K$) o recursos actuales disminuyen tras varios turnos de extracción, **When** el usuario observa la celda en la vista estándar sin cambiar de lente, **Then** la celda refleja visualmente tanto el nivel relativo de recursos disponibles como cualquier cicatriz o alerta visual de degradación ecológica ($K < K_{\max}$).

---

### User Story 2 - Fichas Expresivas de Habitantes (*Demes*) con Acción Dominante, Estado Vital y Cultura (Priority: P1)

Como jugador, quiero que cada subpoblación (*deme*) en el mapa se represente mediante una ficha expresiva que muestre, además de su tamaño poblacional y color de linaje, un icono de su decisión dominante actual, un anillo de estado vital/energético y una marca distintiva cuando posea tradiciones culturales activas, para comprender qué estrategia sigue cada grupo y cuál es su salud demográfica sin necesidad de seleccionarlos uno por uno.

**Why this priority**: Permite leer el comportamiento emergente de todas las poblaciones simultáneamente sobre el tablero tras cada turno generacional.

**Independent Test**: Puede probarse ejecutando un turno generacional y comprobando que cada *deme* en el mapa actualiza su insignia de intención según el arquetipo de su decisión dominante (`forage`, `overexploit`, `migrate`, `cooperate`, `exchange`, `dispute`, `innovate`, `custom`), colorea su anillo de estado vital según su balance calórico (`thriving`, `stable`, `struggling`, `starving`) y muestra el distintivo cultural si tiene al menos una tradición cultural activa.

**Acceptance Scenarios**:

1. **Given** cualquier *deme* presente en el mapa tras evaluar un turno generacional, **When** el usuario observa su ficha en el hexágono, **Then** la ficha muestra una insignia con un icono inequívoco correspondiente al arquetipo de su decisión dominante actual.
2. **Given** *demes* con distintos balances energéticos y reservas calóricas, **When** se renderizan en el mapa, **Then** cada ficha muestra un anillo perimetral codificado visualmente según su estado vital (prosperando, estable, en dificultades o en hambruna) coincidente con el diagnóstico del panel de contexto.
3. **Given** un *deme* que posee o adquiere al menos una tradición cultural activa, **When** se muestra en el mapa, **Then** su ficha exhibe un indicador visual de cultura que lo distingue de las poblaciones puramente biológicas.

---

### User Story 3 - Arcos Animados de Interacción Directa Deme-a-Deme (Priority: P1)

Como jugador, quiero que las interacciones de migración, intercambio simbiótico y disputa territorial se representen mediante arcos direccionales animados que conecten directamente las fichas de las subpoblaciones (*demes*) participantes —tanto cuando cohabitan dentro del mismo hexágono como cuando interactúan entre hexágonos adyacentes—, para identificar con exactitud qué grupos están comerciando, compitiendo o escindiéndose en cada generación.

**Why this priority**: Resuelve el principal problema de legibilidad actual, donde las disputas e intercambios dentro de un mismo hexágono se dibujaban como un círculo genérico alrededor de la celda sin indicar qué habitantes interactuaban entre sí.

**Independent Test**: Puede probarse en un turno donde cohabiten 2 o 3 *demes* en un mismo hexágono con decisiones de *Disputa Territorial* o *Intercambio / Simbiosis*, y donde otro *deme* ejecute *Migración Selectiva* hacia un hexágono vecino, verificando que los arcos animados conectan directamente la posición de la ficha origen con la posición de la ficha destino y muestran un marcador central del tipo de interacción.

**Acceptance Scenarios**:

1. **Given** dos *demes* que cohabitan en el mismo hexágono y protagonizan una *Disputa Territorial* (Halcón vs. Halcón o Halcón vs. Paloma) o un *Intercambio / Simbiosis*, **When** se renderizan los flujos del turno, **Then** el mapa dibuja un arco animado directo entre las coordenadas de ambas fichas dentro del hexágono (en lugar de un círculo genérico alrededor de la celda), con el estilo y símbolo correspondientes al conflicto o al intercambio.
2. **Given** dos *demes* situados en hexágonos vecinos que realizan un *Intercambio / Simbiosis* inter-hexagonal, o un *deme* que origina una subpoblación migrante en un hexágono adyacente, **When** se renderizan los flujos del turno, **Then** el mapa traza un arco curvo animado desde la ficha del *deme* origen hasta la ficha del *deme* receptor o migrante en la celda vecina.
3. **Given** el puntero del usuario situado sobre un hexágono con interacciones activas en el turno actual, **When** se muestra la tarjeta informativa emergente (*hover card*), **Then** la tarjeta resume los habitantes presentes con su acción dominante y las interacciones activas registradas en esa celda.

---

### User Story 4 - Navegación Interactiva con Zoom y Paneo en el Mapa (Priority: P2)

Como jugador, quiero poder acercar, alejar y desplazar libremente la cámara del mapa (tanto mediante gestos de rueda/arrastre como mediante botones accesibles en pantalla para acercar, alejar y encuadrar el mapa completo), para examinar con detalle las interacciones locales dentro de hexágonos con múltiples habitantes sin perder la capacidad de volver rápidamente a la vista general.

**Why this priority**: Al añadir mayor riqueza visual en cada celda (relieve, iconos de acción, anillos vitales y arcos intra-celda entre hasta 3 *demes*), el usuario necesita poder acercarse a las zonas de actividad densa sin que los elementos se solapen.

**Independent Test**: Puede probarse usando los controles de `+`, `-` y `Restablecer vista` en el mapa, así como la rueda del ratón y el arrastre del lienzo en modo inspección, verificando que el mapa se amplía y desplaza suavemente dentro de límites acotados sin interferir con la selección de celdas/habitantes ni con el uso de los pinceles de presión selectiva.

**Acceptance Scenarios**:

1. **Given** el mapa en cualquier nivel de zoom, **When** el usuario utiliza los botones de control de cámara (`Acercar`, `Alejar`, `Ajustar vista`) o la rueda de desplazamiento sobre el mapa, **Then** la escala visual cambia entre un nivel mínimo (vista completa del mundo) y un nivel máximo de detalle manteniendo la nitidez de todos los elementos.
2. **Given** el mapa ampliado y la herramienta de inspección activa, **When** el usuario arrastra el lienzo o utiliza los controles de navegación, **Then** la vista se desplaza por el mapa sin activar selecciones accidentales, y cuando hay un pincel de presión selectiva activo, el arrastre sobre las celdas continúa aplicando el pincel como se espera.

### Edge Cases

- **Coexistencia de hasta 3 *Demes* en un mismo Hexágono con Múltiples Interacciones:** Cuando 3 *demes* cohabitan en la misma celda y varios de ellos disputan o intercambian recursos simultáneamente, las posiciones de las 3 fichas deben mantener una separación suficiente y los arcos intra-hexágono deben curvarse entre cada par de fichas sin ocultar las cifras de población ni las insignias de decisión dominante.
- **Compatibilidad con Partidas Guardadas o Flujos sin Destinatario Específico:** Si se importa una partida guardada previamente cuyos registros de flujo del turno solo contienen las celdas de origen y destino pero no el identificador explícito del *deme* receptor, el mapa debe resolver automáticamente la conexión hacia el *deme* correspondiente en la celda destino o hacia el centro de la celda sin fallos visuales.
- **Respeto a Preferencias de Movimiento Reducido (`prefers-reduced-motion`):** Si el sistema operativo o navegador del usuario tiene activada la preferencia de reducción de movimiento, los arcos de interacción y pulsos de eventos deben mostrarse con trazos estáticos claros sin animaciones continuas.
- **Conmutación de Lentes del Mapa (`Bioma`, `Alimento`, `Salud`):** Cuando el usuario cambia expresamente a la lente de `Alimento` o `Salud`, el relieve 2.5D y las fichas/interacciones de los habitantes permanecen visibles mientras el color de la superficie de cada celda adopta la escala cromática de la lente seleccionada.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001 (Relieve Topográfico 2.5D por Altitud)**: El mapa hexagonal MUST representar cada celda con un borde lateral o extrusión inferior 2.5D y sombreado cuya profundidad visual escale proporcionalmente a la propiedad `altitude` ($[0.0, 1.0]$) de la celda, diferenciando claramente las depresiones oceánicas sumergidas de las tierras bajas, mesetas y cordilleras de alta montaña.
- **FR-002 (Ilustración Topográfica por Bioma)**: En la vista de biomas, cada celda MUST renderizar un motivo gráfico ilustrado característico de su tipo de bioma (`tropical_forest`, `savanna`, `arid_steppe`, `tundra`, `high_mountain`, `coastal_shallows`, `ocean`), además de su color base y contorno costal cuando limite con celdas oceánicas.
- **FR-003 (Indicadores Integrados de Recursos y Degradación Ecológica)**: Cada celda terrestre MUST mostrar directamente sobre el terreno, sin necesidad de cambiar de lente, (a) un indicador visual proporcional a la abundancia de recursos actuales respecto a su capacidad máxima (`currentResources / carryingCapacityMax`), y (b) un indicador visual de degradación ecológica cuando la capacidad de carga actual haya caído significativamente por debajo de su máximo (`carryingCapacity < 0.85 * carryingCapacityMax`).
- **FR-004 (Insignia de Acción Dominante en cada *Deme*)**: Cada ficha de *deme* en el mapa MUST mostrar un icono distintivo correspondiente al arquetipo de su última decisión dominante (`forage`, `overexploit`, `migrate`, `cooperate`, `exchange`, `dispute`, `innovate` o `custom`), acompañado de su descripción accesible.
- **FR-005 (Anillo de Estado Vital e Indicador Cultural del *Deme*)**: Cada ficha de *deme* MUST mostrar un anillo de estado codificado según su situación energética (`thriving`, `stable`, `struggling`, `starving`) y un distintivo visual adicional cuando el *deme* posea al menos una tradición cultural activa (`culturalTraitIds.length > 0`).
- **FR-006 (Arcos Animados Directos *Deme-a-Deme*)**: Los flujos de interacción del turno (`migration`, `exchange`, `dispute`) MUST vincular al *deme* emisor con el *deme* receptor o con el par de *demes* que interactúan (tanto dentro del mismo hexágono como entre hexágonos vecinos), dibujando arcos curvos direccionales animados con iconografía de interacción en el punto medio del arco.
- **FR-007 (Tarjeta Emergente Enriquecida e Internacionalización)**: La tarjeta emergente (*hover card*) al pasar el cursor sobre un hexágono y la leyenda del mapa MUST mostrar en el idioma activo del usuario (con inglés `en` por defecto y soporte para los 8 idiomas del simulador) el estado de los habitantes presentes (incluyendo su acción dominante y estado vital) y las claves visuales de las interacciones.
- **FR-008 (Controles de Zoom y Paneo del Mapa)**: El lienzo del mapa MUST ofrecer controles interactivos de acercamiento (`Zoom In`), alejamiento (`Zoom Out`), restablecimiento de encuadre (`Reset View`) y desplazamiento panorámico (*Pan*), manteniendo intacta la funcionalidad de selección de celdas/*demes* y la aplicación de pinceles de presión selectiva.

### Key Entities

- **HexCell Visual Projection**: Representación espacial 2.5D de una celda hexagonal que combina su polígono superior, cara de relieve lateral según `altitude`, motivo ilustrado de `biome`, borde costero e indicadores integrados de recursos y salud del hábitat.
- **Deme Visual Token**: Representación gráfica de una subpoblación local dentro de su celda, compuesta por su círculo poblacional escalado, anillo de estado vital (`thriving` | `stable` | `struggling` | `starving`), insignia de arquetipo de decisión dominante e indicador de cultura activa.
- **HexEdgeFlow (Vínculo de Interacción)**: Registro de interacción del turno entre subpoblaciones (`migration`, `exchange`, `dispute`), incluyendo la celda de origen (`fromHexId`), celda de destino (`toHexId`), *deme* emisor (`demeId`), *deme* receptor opcional (`targetDemeId`), color, tipo e intensidad para trazar arcos directos *deme-a-deme*.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los 7 tipos de bioma y los distintos niveles de altitud se distinguen visualmente en el mapa mediante relieve 2.5D y motivos gráficos propios sin necesidad de abrir el panel lateral.
- **SC-002**: El 100% de los *demes* visibles en el tablero muestran simultáneamente su población, su estado vital (4 niveles) y el icono de su decisión dominante actual (8 arquetipos soportados).
- **SC-003**: El 100% de las interacciones del turno (disputas intra-celda, intercambios intra/inter-celda y migraciones) se dibujan como conexiones directas entre las fichas de los *demes* involucrados, eliminando los círculos ambiguos alrededor del hexágono completo cuando hay múltiples habitantes.
- **SC-004**: El usuario puede ampliar el mapa al menos hasta un factor de $2.5\times$ sobre cualquier hexágono poblado, desplazar la vista y restablecer el encuadre original con un solo clic, manteniendo el 100% de las pruebas unitarias, de contrato y de integración en verde.

## Assumptions

- Se conserva íntegramente el modelo matemático, biofísico y cognitivo existente; las mejoras se centran en la expresividad visual del tablero, la navegación espacial y la precisión del vínculo entre habitantes que interactúan.
- El campo de identificador del *deme* receptor en los flujos del turno es opcional para garantizar compatibilidad total hacia atrás con partidas exportadas o guardadas antes de esta mejora.
- El idioma por defecto de todas las nuevas etiquetas y leyendas sigue siendo inglés (`en`), con traducciones completas en los 8 idiomas soportados (`en`, `es`, `zh`, `fr`, `de`, `pt`, `ja`, `ru`).
