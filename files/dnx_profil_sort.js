/* =====================================================================
   DNX Profil-Sortierung  v1.0.1
   ---------------------------------------------------------------------
   Sortiert das Profil-Aufklappmenue des Receivers nach Frequenz -
   aufsteigend, also von der niedrigsten zur hoechsten Frequenz.

   Warum: OpenWebRX stellt die Profile in der Reihenfolge der
   Konfigurationsdatei dar. Werden spaeter weitere Geraete oder Profile
   ergaenzt, haengen die hinten an - und die Liste beginnt irgendwo,
   z. B. bei 30-32 MHz, waehrend ULF/VLF/LF/MW/KW ganz unten stehen.

   Was es tut:
     - liest die Frequenzen aus static/plugins/wf_profiles.json
       (dieselbe Datei, die auch die DNX-Profiltabelle nutzt)
     - ordnet die Eintraege im Menue aufsteigend nach Frequenz
     - laesst die Auswahl unangetastet
     - sortiert neu, sobald der Receiver die Liste neu aufbaut

   Was es NICHT tut:
     - keine Aenderung an settings.json oder an den Profilen selbst
     - kein Eingriff in Rechte; die Sperre fuer Gaeste bleibt, wie sie ist
     - die DNX-Profiltabelle (Knoopf "Profile") bleibt unberuehrt,
       sie sortiert selbst

   Private, inoffizielle Hobby-Anpassung; kein offizielles
   OpenWebRX-/OpenWebRX+-Projekt. Nutzung auf eigene Gefahr.
   ===================================================================== */
(function () {
    "use strict";
    if (window.__dnxProfilSort) { return; }
    window.__dnxProfilSort = true;

    var LISTE  = "openwebrx-sdr-profiles-listbox";
    var META   = "static/plugins/wf_profiles.json";
    var TAKT   = 1500;

    var meta = null;         /* "geraet|profil" -> {f,m,s,n} */
    var signatur = "";       /* zuletzt hergestellte Reihenfolge */

    function metadaten(fertig) {
        if (meta) { fertig(true); return; }
        try {
            var r = new XMLHttpRequest();
            r.open("GET", META, true);
            r.onreadystatechange = function () {
                if (r.readyState !== 4) { return; }
                if (r.status === 200 || r.status === 0) {
                    try { meta = JSON.parse(r.responseText) || {}; } catch (eP) { meta = null; }
                }
                fertig(!!meta);
            };
            r.send(null);
        } catch (eR) { fertig(false); }
    }

    function frequenz(wert) {
        if (!meta) { return null; }
        var t = String(wert || "").split("|");
        var e = meta[t[0] + "|" + t[1]];
        if (e && typeof e.f === "number") { return e.f; }
        return null;
    }

    /* Profilname zu einem Wert, z. B. "ULF 0.3-3 kHz" oder "HAM 2200m 135.7-137.8 kHz".
       Das braucht es bei gleicher Mittenfrequenz: 0.3-3 kHz, 3-30 kHz und 30-100 kHz
       stehen in den Profilen alle auf 125 kHz. */
    function name(wert) {
        if (!meta) { return ""; }
        var t = String(wert || "").split("|");
        var e = meta[t[0] + "|" + t[1]];
        return (e && e.n) ? String(e.n) : "";
    }

    var BEREICH = /([0-9]+(?:[.,][0-9]+)?)\s*[\u2010-\u2015-]\s*[0-9]+(?:[.,][0-9]+)?\s*(k|m)Hz/i;
    var EINZELN = /([0-9]+(?:[.,][0-9]+)?)\s*(k|m)Hz/i;

    function hz(zahl, einheit) {
        var z = parseFloat(String(zahl).replace(",", "."));
        if (isNaN(z)) { return null; }
        return String(einheit).toLowerCase() === "k" ? z * 1e3 : z * 1e6;
    }

    function unterkante(text) {
        var t = String(text || "");
        var m = BEREICH.exec(t);                       /* "0.3-3 kHz" -> 0.3 kHz */
        if (m) { return hz(m[1], m[2]); }
        m = EINZELN.exec(t);                           /* sonst die erste Angabe */
        if (m) { return hz(m[1], m[2]); }
        return null;                                   /* ohne Einheit nicht raten */
    }

    function sortieren() {
        var lb = document.getElementById(LISTE);
        if (!lb || !lb.options || !lb.options.length || !meta) { return false; }

        var opts = [];
        for (var i = 0; i < lb.options.length; i++) { opts.push(lb.options[i]); }

        opts.sort(function (a, b) {
            var fa = frequenz(a.value), fb = frequenz(b.value);
            if (fa === null && fb === null) { return 0; }
            if (fa === null) { return 1; }        /* ohne Frequenz ans Ende */
            if (fb === null) { return -1; }
            if (fa !== fb) { return fa - fb; }
            var ua = unterkante(name(a.value)), ub = unterkante(name(b.value));
            if (ua !== null && ub !== null && ua !== ub) { return ua - ub; }
            return String(a.textContent || "").localeCompare(String(b.textContent || ""), "de");
        });

        var neu = [];
        for (var k = 0; k < opts.length; k++) { neu.push(opts[k].value); }
        var sig = neu.join("|");
        if (sig === signatur) { return false; }   /* steht schon so */

        var gewaehlt = lb.value;
        for (var m = 0; m < opts.length; m++) { lb.appendChild(opts[m]); }
        try { lb.value = gewaehlt; } catch (eV) { }
        signatur = sig;
        return true;
    }

    /* Liste beobachten: baut der Receiver sie neu, wird neu sortiert. */
    function beobachten() {
        var lb = document.getElementById(LISTE);
        if (!lb) { return false; }
        if (lb.__dnxSortBeobachtet) { return true; }
        lb.__dnxSortBeobachtet = true;
        try {
            var mo = new MutationObserver(function () {
                try { sortieren(); } catch (eS) { }
            });
            mo.observe(lb, { childList: true });
        } catch (eM) { }
        return true;
    }

    metadaten(function () {
        sortieren();
        beobachten();
        /* Sicherheitsnetz: die Liste entsteht teils spaeter */
        var versuche = 0;
        var t = setInterval(function () {
            versuche++;
            beobachten();
            sortieren();
            if (versuche > 40) { clearInterval(t); }
        }, TAKT);
    });
})();
