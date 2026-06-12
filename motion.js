/* =========================================================
   RA.RO atelier — motion
   smooth scroll · word reveal · scroll-zoom · grow-to-fullscreen
   ========================================================= */
(function () {
  "use strict";
  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------- word splitter ---------- */
  function splitWords(el) {
    var text = el.textContent;
    // preserve existing inner markup nodes (em/span) by walking children
    var frag = document.createDocumentFragment();
    var nodes = Array.prototype.slice.call(el.childNodes);
    var counter = { i: 0 };
    nodes.forEach(function (node) {
      if (node.nodeType === 3) {
        appendWords(frag, node.textContent, counter, null);
      } else if (node.nodeType === 1) {
        // wrap words but keep the element's tag/classes on each word
        appendWords(frag, node.textContent, counter, node);
      }
    });
    el.innerHTML = "";
    el.appendChild(frag);
  }
  function appendWords(frag, str, counter, styleEl) {
    var parts = str.split(/(\s+)/);
    parts.forEach(function (p) {
      if (p === "") return;
      if (/^\s+$/.test(p)) {
        frag.appendChild(document.createTextNode(" "));
        return;
      }
      var word = document.createElement("span");
      word.className = "word";
      var inner = document.createElement("i");
      inner.textContent = p;
      inner.style.setProperty("--i", counter.i++);
      if (styleEl) {
        inner.className = styleEl.className || "";
        // inherit color styling cues like .terra / .dim / em
        if (styleEl.tagName.toLowerCase() === "em") inner.style.fontStyle = "italic";
      }
      word.appendChild(inner);
      frag.appendChild(word);
    });
  }

  document.querySelectorAll("[data-split]").forEach(splitWords);

  /* ---------- scroll-driven reveals (IntersectionObserver is unreliable
       inside some preview iframes, so we compute against the viewport) ---------- */
  var revealEls = Array.prototype.slice.call(document.querySelectorAll(".reveal, .split"));
  function checkReveals(h) {
    var trigger = h * 0.88;
    for (var i = revealEls.length - 1; i >= 0; i--) {
      var el = revealEls[i];
      var r = el.getBoundingClientRect();
      if (r.top < trigger && r.bottom > 0) {
        el.classList.add("is-in");
        revealEls.splice(i, 1);
      }
    }
  }

  /* ---------- nav scrolled state + progress + year ---------- */
  var nav = document.getElementById("nav");
  var progress = document.getElementById("progress");
  var yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  /* ---------- elements for scroll-driven motion ---------- */
  var heroMedia = document.getElementById("heroMedia");
  var growSection = document.getElementById("grow");
  var growFrame = document.getElementById("growFrame");
  var growImg = document.getElementById("growImg");
  var growCap = document.getElementById("growCap");

  function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
  function lerp(a, b, t) { return a + (b - a) * t; }

  var vh = window.innerHeight;
  var narrow = window.innerWidth < 720;
  window.addEventListener("resize", function () {
    vh = window.innerHeight;
    narrow = window.innerWidth < 720;
  });

  function onScroll(scrollY) {
    // nav
    if (scrollY > 40) nav.classList.add("scrolled"); else nav.classList.remove("scrolled");
    // progress
    var max = document.documentElement.scrollHeight - vh;
    progress.style.width = (clamp(scrollY / (max || 1), 0, 1) * 100) + "%";

    checkReveals(vh);

    if (reduce) return;

    // hero zoom + drift
    if (heroMedia) {
      var hp = clamp(scrollY / vh, 0, 1);
      heroMedia.style.transform = "scale(" + (1 + hp * 0.16) + ") translateY(" + (hp * -3) + "%)";
      heroMedia.style.opacity = (1 - hp * 0.55).toFixed(3);
    }

    // grow-to-fullscreen
    if (growSection && growFrame) {
      var rect = growSection.getBoundingClientRect();
      var total = rect.height - vh;
      var prog = clamp((-rect.top) / (total || 1), 0, 1);
      // ease
      var e = prog < 0.5 ? 4 * prog * prog * prog : 1 - Math.pow(-2 * prog + 2, 3) / 2;
      // em telas estreitas o quadro inicial precisa ser maior para ter presença
      var w = lerp(narrow ? 86 : 42, 100, e);
      var h = lerp(narrow ? 46 : 54, 100, e);
      growFrame.style.width = w + "vw";
      growFrame.style.height = h + "svh";
      growFrame.style.borderColor = "rgba(244,241,234," + (0.12 * (1 - e)) + ")";
      if (growImg) growImg.style.transform = "scale(" + lerp(1.18, 1.0, e) + ")";
      if (growCap) growCap.classList.toggle("show", prog > 0.55);
    }
  }

  function currentScroll() { return window.scrollY || window.pageYOffset || 0; }

  /* native scroll listener (also fires while Lenis drives scrollTop) */
  var ticking = false;
  window.addEventListener("scroll", function () {
    if (!ticking) {
      requestAnimationFrame(function () { onScroll(currentScroll()); ticking = false; });
      ticking = true;
    }
  }, { passive: true });

  /* ---------- Lenis smooth scroll ---------- */
  var lenis = null;
  if (window.Lenis && !reduce) {
    lenis = new window.Lenis({
      duration: 1.15,
      easing: function (t) { return Math.min(1, 1.001 - Math.pow(2, -10 * t)); },
      smoothWheel: true,
      lerp: 0.085
    });
    lenis.on("scroll", function (e) {
      onScroll(e && e.animatedScroll != null ? e.animatedScroll : currentScroll());
    });
    var raf = function (time) { lenis.raf(time); requestAnimationFrame(raf); };
    requestAnimationFrame(raf);
  }

  /* Engage motion ONLY when a real animation frame fires (i.e. the page is
     actually being rendered). If the clock is paused (inactive tab, print,
     export, capture) html.motion is never added and everything stays visible. */
  if (reduce) {
    onScroll(currentScroll());
  } else {
    requestAnimationFrame(function () {
      document.documentElement.classList.add("motion");
      requestAnimationFrame(function () { onScroll(currentScroll()); });
    });
  }

  /* ---------- anchor smooth scroll ---------- */
  document.querySelectorAll('a[href^="#"]').forEach(function (a) {
    a.addEventListener("click", function (ev) {
      var id = a.getAttribute("href");
      // links placeholder (ex.: loja ainda sem URL) não devem pular ao topo
      if (id === "#" || id.length < 2) { ev.preventDefault(); return; }
      var target = document.querySelector(id);
      if (!target) return;
      ev.preventDefault();
      if (lenis) lenis.scrollTo(target, { offset: -10, duration: 1.3 });
      else target.scrollIntoView({ behavior: "smooth" });
    });
  });

  /* ---------- FAQ accordion ---------- */
  document.querySelectorAll("#faqList .fitem").forEach(function (item) {
    var btn = item.querySelector(".fq");
    var panel = item.querySelector(".fa");
    var inner = item.querySelector(".fa-inner");
    btn.addEventListener("click", function () {
      var isOpen = item.classList.contains("open");
      document.querySelectorAll("#faqList .fitem.open").forEach(function (o) {
        if (o !== item) { o.classList.remove("open"); o.querySelector(".fa").style.height = "0px"; }
      });
      if (isOpen) { item.classList.remove("open"); panel.style.height = "0px"; }
      else { item.classList.add("open"); panel.style.height = inner.offsetHeight + "px"; }
    });
  });
  window.addEventListener("resize", function () {
    var open = document.querySelector("#faqList .fitem.open");
    if (open) open.querySelector(".fa").style.height = open.querySelector(".fa-inner").offsetHeight + "px";
  });

  /* ---------- form ---------- */
  var form = document.getElementById("quoteForm");
  if (form) {
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var nome = form.querySelector('[name="nome"]');
      var email = form.querySelector('[name="email"]');
      var ok = true;
      [nome, email].forEach(function (f) {
        if (!f.value.trim()) { f.style.borderBottomColor = "var(--terra)"; ok = false; }
      });
      if (!ok) return;
      form.classList.add("sent");
      var msg = document.getElementById("sentMsg");
      if (msg) msg.classList.add("show");
    });
  }

  /* ---------- mobile menu ---------- */
  var toggle = document.getElementById("navToggle");
  var mmenu = document.getElementById("mmenu");
  function setMenu(open) {
    if (!mmenu || !toggle) return;
    mmenu.classList.toggle("open", open);
    document.body.classList.toggle("menu-open", open);
    toggle.textContent = open ? "Fechar" : "Menu";
    toggle.setAttribute("aria-expanded", open ? "true" : "false");
  }
  if (toggle && mmenu) {
    toggle.addEventListener("click", function () {
      setMenu(!mmenu.classList.contains("open"));
    });
    mmenu.querySelectorAll("a").forEach(function (a) {
      a.addEventListener("click", function () { setMenu(false); });
    });
  }

  /* ---------- quadros: arrastar para rolar (desktop) ---------- */
  var strip = document.getElementById("qstrip");
  if (strip && window.PointerEvent) {
    var dragOn = false, dragX = 0, dragLeft = 0;
    strip.addEventListener("pointerdown", function (e) {
      if (e.pointerType !== "mouse") return; // touch usa o scroll nativo
      dragOn = true; dragX = e.clientX; dragLeft = strip.scrollLeft;
      strip.classList.add("dragging");
      strip.setPointerCapture(e.pointerId);
    });
    strip.addEventListener("pointermove", function (e) {
      if (!dragOn) return;
      strip.scrollLeft = dragLeft - (e.clientX - dragX);
    });
    ["pointerup", "pointercancel"].forEach(function (t) {
      strip.addEventListener(t, function () {
        dragOn = false; strip.classList.remove("dragging");
      });
    });
  }
})();
