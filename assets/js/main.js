/* Willy Linux — comportamiento de la página.
   Sin dependencias: el tema se guarda en localStorage y los datos de la ISO se leen
   de datos-iso.json, que es el unico sitio donde viven el tamano y el SHA-256. */

(function () {
  "use strict";

  // ---------- tema ----------
  var CLAVE_TEMA = "willy-tema";

  function aplicarTema(t) {
    var raiz = document.documentElement;
    if (t === "claro") { raiz.classList.add("claro"); }
    else if (t === "oscuro") { raiz.classList.remove("claro"); }
    else { raiz.classList.remove("claro"); } // "auto" sigue prefers-color-scheme
  }

  function textoBoton(t) {
    return t === "claro" ? "Tema: claro" : t === "oscuro" ? "Tema: oscuro" : "Tema: auto";
  }

  function iniciarTema() {
    var boton = document.getElementById("tema");
    if (!boton) return;
    var actual = localStorage.getItem(CLAVE_TEMA) || "auto";
    aplicarTema(actual);
    boton.textContent = textoBoton(actual);
    boton.addEventListener("click", function () {
      var orden = ["auto", "claro", "oscuro"];
      var siguiente = orden[(orden.indexOf(actual) + 1) % orden.length];
      actual = siguiente;
      localStorage.setItem(CLAVE_TEMA, actual);
      aplicarTema(actual);
      boton.textContent = textoBoton(actual);
    });
  }

  // ---------- datos de la ISO ----------
  // Cubre cualquier elemento con data-dato="ruta.hasta.el.campo".
  function valorEn(objeto, ruta) {
    return ruta.split(".").reduce(function (acc, parte) {
      return acc == null ? undefined : acc[parte];
    }, objeto);
  }

  function formatearBytes(n) {
    if (typeof n !== "number" || !isFinite(n)) return "—";
    var mb = n / 1048576;
    var miles = mb.toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g, ".");
    return miles + " MB · " + n.toLocaleString("es-ES") + " B";
  }

  function rellenar(datos) {
    document.querySelectorAll("[data-dato]").forEach(function (el) {
      var v = valorEn(datos, el.getAttribute("data-dato"));
      if (v == null) { el.textContent = "—"; return; }
      if (el.hasAttribute("data-enlaces")) {
        // "url|texto , url|texto" -> enlaces separados por un punto medio
        el.textContent = "";
        String(v).split(",").forEach(function (par, i) {
          var trozos = par.split("|");
          if (i) el.appendChild(document.createTextNode(" · "));
          var a = document.createElement("a");
          a.href = trozos[0].trim();
          a.textContent = (trozos[1] || trozos[0]).trim();
          a.target = "_blank";
          a.rel = "noopener";
          el.appendChild(a);
        });
        return;
      }
      if (el.tagName === "A") { el.href = v; }
      el.textContent = el.hasAttribute("data-bytes") ? formatearBytes(v) : String(v);
    });

    var hash = valorEn(datos, "iso.sha256");
    document.querySelectorAll("[data-copiar-hash]").forEach(function (boton) {
      if (!hash) return;
      boton.disabled = false;
      boton.addEventListener("click", function () {
        copiar(hash, boton);
      });
    });
  }

  function copiar(texto, boton) {
    function listo() {
      var previo = boton.textContent;
      boton.textContent = "copiado";
      setTimeout(function () { boton.textContent = previo; }, 1600);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(texto).then(listo, function () { fallback(texto, boton); });
    } else {
      fallback(texto, boton);
    }
  }

  function fallback(texto, boton) {
    var campo = document.createElement("textarea");
    campo.value = texto;
    campo.setAttribute("readonly", "");
    campo.style.position = "fixed";
    campo.style.left = "-9999px";
    document.body.appendChild(campo);
    campo.select();
    try { document.execCommand("copy"); } catch (e) { /* sin portapapeles: se puede seleccionar a mano */ }
    document.body.removeChild(campo);
    var previo = boton.textContent;
    boton.textContent = "copiado";
    setTimeout(function () { boton.textContent = previo; }, 1600);
  }

  function cargarDatos() {
    var origen = document.body.getAttribute("data-datos") || "datos-iso.json";
    fetch(origen, { cache: "no-store" })
      .then(function (r) { if (!r.ok) throw new Error("HTTP " + r.status); return r.json(); })
      .then(rellenar)
      .catch(function (err) {
        // Si no se puede leer (por ejemplo abriendo el HTML con file://), el HTML ya
        // trae los valores escritos a mano: no se rompe nada visible.
        document.querySelectorAll("[data-dato]").forEach(function (el) {
          if (!el.textContent.trim()) el.textContent = "—";
        });
        var nota = document.getElementById("datos-aviso");
        if (nota) nota.hidden = false;
        if (window.console) console.warn("datos-iso.json no disponible:", err.message);
      });
  }

  // ---------- buscador de ayuda ----------
  function iniciarBuscador() {
    var campo = document.getElementById("buscar-ayuda");
    if (!campo) return;
    var tarjetas = Array.prototype.slice.call(document.querySelectorAll("[data-buscable]"));
    var contador = document.getElementById("buscador-recuento");

    function filtrar() {
      var q = campo.value.trim().toLowerCase();
      var vistos = 0;
      tarjetas.forEach(function (el) {
        var coincide = !q || el.textContent.toLowerCase().indexOf(q) !== -1;
        el.hidden = !coincide;
        if (coincide) vistos++;
        if (q && coincide && el.tagName === "DETAILS") el.open = true;
      });
      if (contador) contador.textContent = q ? vistos + " de " + tarjetas.length : tarjetas.length + " apartados";
    }

    campo.addEventListener("input", filtrar);
    campo.addEventListener("search", filtrar);
    filtrar();
  }

  // ---------- navegación activa por sección larga ----------
  function iniciarAnclas() {
    var enlaces = Array.prototype.slice.call(document.querySelectorAll(".indice a"));
    if (!enlaces.length) return;
    var mapa = {};
    enlaces.forEach(function (a) {
      var id = a.getAttribute("href").slice(1);
      var seccion = document.getElementById(id);
      if (seccion) mapa[id] = a;
    });
    if (!("IntersectionObserver" in window)) return;
    var observador = new IntersectionObserver(function (entradas) {
      entradas.forEach(function (e) {
        var a = mapa[e.target.id];
        if (!a) return;
        if (e.isIntersecting) {
          enlaces.forEach(function (x) { x.classList.remove("activa"); });
          a.classList.add("activa");
        }
      });
    }, { rootMargin: "-40% 0px -55% 0px" });
    Object.keys(mapa).forEach(function (id) { observador.observe(document.getElementById(id)); });
  }

  document.addEventListener("DOMContentLoaded", function () {
    iniciarTema();
    cargarDatos();
    iniciarBuscador();
    iniciarAnclas();
  });
})();
