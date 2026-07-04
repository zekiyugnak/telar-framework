/* Telar documentation — shared behavior. Vanilla JS, no dependencies. */
(function () {
  "use strict";

  // Mobile nav toggle
  var toggle = document.querySelector(".nav-toggle");
  var links = document.querySelector(".nav-links");
  if (toggle && links) {
    toggle.addEventListener("click", function () {
      links.classList.toggle("open");
    });
  }

  // Mark the active top-nav link based on the current file name
  var here = location.pathname.split("/").pop() || "index.html";
  document.querySelectorAll(".nav-links a").forEach(function (a) {
    var href = a.getAttribute("href");
    if (href === here || (here === "" && href === "index.html")) {
      a.classList.add("active");
    }
  });

  // Accordion: expand/collapse a card's detail panel
  document.querySelectorAll(".card-toggle").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var detail = btn.parentElement.querySelector(".card-detail");
      if (!detail) return;
      var open = btn.getAttribute("aria-expanded") === "true";
      btn.setAttribute("aria-expanded", String(!open));
      detail.hidden = open;
      btn.textContent = open ? "Details" : "Hide";
    });
  });

  // Per-page instant filter: narrows visible cards by typed text.
  var input = document.getElementById("filter");
  if (input) {
    var cards = Array.prototype.slice.call(document.querySelectorAll(".card"));
    var groups = Array.prototype.slice.call(document.querySelectorAll(".group"));
    var meta = document.getElementById("filter-meta");
    var total = cards.length;

    function apply() {
      var q = input.value.trim().toLowerCase();
      var shown = 0;
      cards.forEach(function (c) {
        var hay = (c.getAttribute("data-search") || c.textContent).toLowerCase();
        var match = q === "" || hay.indexOf(q) !== -1;
        c.classList.toggle("hidden", !match);
        if (match) shown++;
      });
      // hide groups with no visible cards
      groups.forEach(function (g) {
        var any = g.querySelector(".card:not(.hidden)");
        g.classList.toggle("hidden", !any);
      });
      if (meta) {
        meta.textContent = q === ""
          ? total + " items"
          : shown + " / " + total + " match “" + input.value + "”";
      }
    }
    input.addEventListener("input", apply);
    apply();
  }
})();
