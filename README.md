# 🚀 Freeline Animex

**Freeline Animex** es una aplicación móvil desarrollada en Flutter diseñada para la visualización de contenido multimedia de forma eficiente, limpia y sin interrupciones publicitarias. El proyecto se centra en la ingeniería de extracción de datos y la reproducción nativa de video.

<img width="717" height="512" alt="Diseño sin título (7)" src="https://github.com/user-attachments/assets/3111df33-bd93-4c91-9f95-1548aafceefa" />


## 🛠️ Stack Tecnológico
* **Framework:** Flutter (Dart)
* **Gestión de Estado:** Provider
* **Reproducción de Video:** Chewie & Video Player (Soporte Nativo HLS)
* **Persistencia:** Shared Preferences (Historial y Favoritos)
* **Networking:** HTTP & Scraper Service (Custom Parsing)

## 🌟 Características Principales
* **Extractor de Video Avanzado:** Lógica personalizada para desofuscar código JavaScript (P.A.C.K.E.R.) y obtener enlaces directos `.m3u8` desde servidores espejo como Niramirus y StreamWish.
* **Experiencia Ad-Free:** Al utilizar reproducción nativa y extracción por detrás (backend-like), se eliminan por completo los anuncios invasivos de los servidores de terceros.
* **Interfaz Moderna:** Diseño oscuro con sistema de búsqueda optimizado por géneros y directorio paginado.
* **Historial Inteligente:** Seguimiento automático de episodios vistos y progreso de reproducción.

## 🧠 Desafíos Técnicos Superados
* **bypass de Protecciones:** Implementación de cabeceras dinámicas y rotación de espejos para evadir bloqueos de referer y geolocalización.
* **Olfateo de Manifiestos:** Algoritmos de expresiones regulares (Regex) ultra-agresivos para identificar el flujo de video real entre miles de líneas de código ofuscado y señuelos (*honey-pots*).
* **Rendimiento:** Transición de una visualización basada en WebView (pesada y con anuncios) a una arquitectura de reproducción nativa mucho más ligera y fluida.

## ⚖️ Licencia
Este proyecto está bajo la Licencia **MIT**. Consulta el archivo [LICENSE](LICENSE) para más detalles.

---
> **Aviso Legal:** Este proyecto ha sido desarrollado exclusivamente con fines educativos y de aprendizaje personal. La aplicación no aloja contenido en servidores propios y se limita a facilitar la visualización de contenido disponible públicamente mediante técnicas de web scraping.
