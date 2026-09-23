/* Jev Chat Assistant site script: version injection / theme / nav / copy / reveal animation */
(function () {
  "use strict";

  var JEV = window.JEV || {};
  var repo = JEV.repo || "https://github.com/jev-chat/jev-chat-jarvis";
  var version = JEV.version || "";
  var apkUrl = JEV.apkUrl || repo;
  if (/(^|\.)chatjevs\.com$/.test(location.hostname) && version) {
    apkUrl = "download/jev-assistant-v" + version + "-release.apk";
  }

  /* ---------- 1. Fill the version number and links everywhere they appear ---------- */
  function fill() {
    var i, els;

    els = document.querySelectorAll("[data-jev-version]");
    for (i = 0; i < els.length; i++) els[i].textContent = version;

    els = document.querySelectorAll("[data-jev-apk]");
    for (i = 0; i < els.length; i++) {
      els[i].setAttribute("href", apkUrl);
      els[i].setAttribute("rel", "noopener");
    }

    var map = [
      ["[data-jev-repo]", repo],
      ["[data-jev-readme]", repo + "#readme"],
      ["[data-jev-issues]", repo + "/issues"],
      ["[data-jev-commits]", repo + "/commits/main"]
    ];
    for (var m = 0; m < map.length; m++) {
      els = document.querySelectorAll(map[m][0]);
      for (i = 0; i < els.length; i++) els[i].setAttribute("href", map[m][1]);
    }
  }
  fill();

  /* ---------- 2. Theme toggle ---------- */
  var root = document.documentElement;
  var themeBtn = document.getElementById("themeBtn");

  function currentTheme() {
    var set = root.getAttribute("data-theme");
    if (set) return set;
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }

  if (themeBtn) {
    themeBtn.addEventListener("click", function () {
      var next = currentTheme() === "dark" ? "light" : "dark";
      root.setAttribute("data-theme", next);
      try { localStorage.setItem("jev-theme", next); } catch (e) {}
    });
  }

  /* ---------- 3. Nav: hamburger menu + scroll outline ---------- */
  var burger = document.getElementById("burger");
  var navMenu = document.getElementById("navMenu");
  var nav = document.getElementById("nav");

  if (burger && navMenu) {
    burger.addEventListener("click", function () {
      var open = navMenu.classList.toggle("open");
      burger.setAttribute("aria-expanded", open ? "true" : "false");
      burger.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    });
    navMenu.addEventListener("click", function (e) {
      if (e.target.tagName === "A") {
        navMenu.classList.remove("open");
        burger.setAttribute("aria-expanded", "false");
        burger.setAttribute("aria-label", "Open menu");
      }
    });
  }

  if (nav) {
    var onScroll = function () {
      if (window.scrollY > 8) nav.classList.add("is-stuck");
      else nav.classList.remove("is-stuck");
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
  }

  /* ---------- 4. Copy the install command ---------- */
  var copyBtn = document.getElementById("copyBtn");
  var cmdText = document.getElementById("cmdText");

  if (copyBtn && cmdText) {
    copyBtn.addEventListener("click", function () {
      var text = cmdText.textContent.trim();
      var label = copyBtn.querySelector(".cmd-copy-label");

      var done = function (ok) {
        if (!label) return;
        label.textContent = ok ? "Copied" : "Copy failed";
        copyBtn.classList.toggle("done", ok);
        setTimeout(function () {
          label.textContent = "Copy";
          copyBtn.classList.remove("done");
        }, 1800);
      };

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function () { done(true); }, function () { done(false); });
      } else {
        try {
          var ta = document.createElement("textarea");
          ta.value = text;
          ta.setAttribute("readonly", "");
          ta.style.position = "fixed";
          ta.style.opacity = "0";
          document.body.appendChild(ta);
          ta.select();
          document.execCommand("copy");
          document.body.removeChild(ta);
          done(true);
        } catch (e) { done(false); }
      }
    });
  }

  /* ---------- 5. Reveal-on-scroll animation ---------- */
  var items = document.querySelectorAll(".reveal");
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  if (reduce || !("IntersectionObserver" in window)) {
    for (var k = 0; k < items.length; k++) items[k].classList.add("in");
  } else {
    var io = new IntersectionObserver(function (entries) {
      for (var j = 0; j < entries.length; j++) {
        if (entries[j].isIntersecting) {
          entries[j].target.classList.add("in");
          io.unobserve(entries[j].target);
        }
      }
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });

    for (var n = 0; n < items.length; n++) {
      // Stagger cards within the same container slightly
      var sibs = items[n].parentElement ? items[n].parentElement.children : [];
      var idx = Array.prototype.indexOf.call(sibs, items[n]);
      if (idx > 0 && idx < 6) items[n].style.transitionDelay = (idx * 70) + "ms";
      io.observe(items[n]);
    }
  }
})();

(function () {
  var JEV = window.JEV || {};
  var repo = JEV.repo || "https://github.com/jev-chat/jev-chat-jarvis";
  // GitHub star count (best effort; falls back to the static number in the markup)
  (function () {
    var els = document.querySelectorAll("[data-jev-stars]");
    if (!els.length || !window.fetch) return;
    var m = /github\.com\/([^/]+\/[^/#?]+)/.exec(repo);
    if (!m) return;
    fetch("https://api.github.com/repos/" + m[1], { headers: { Accept: "application/vnd.github+json" } })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (d) {
        if (!d || typeof d.stargazers_count !== "number") return;
        var n = d.stargazers_count;
        var txt = n >= 1000 ? (Math.round(n / 100) / 10).toFixed(1).replace(/\.0$/, "") + "k" : String(n);
        for (var i = 0; i < els.length; i++) els[i].textContent = txt;
      })
      .catch(function () {});
  })();
})();
