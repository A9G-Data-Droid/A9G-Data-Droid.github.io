document.addEventListener("DOMContentLoaded", function () {
    const themeToggle = document.getElementById("theme-toggle");
    const colorSchemeQuery = window.matchMedia("(prefers-color-scheme: dark)");

    function getActiveTheme() {
        const explicit = document.documentElement.getAttribute("data-theme");
        if (explicit === "dark" || explicit === "light") {
            return explicit;
        }
        return colorSchemeQuery.matches ? "dark" : "light";
    }

    function syncThemeToggle(theme) {
        if (!themeToggle) {
            return;
        }
        const isDark = theme === "dark";
        const label = isDark ? "Switch to light mode" : "Switch to dark mode";
        themeToggle.setAttribute("aria-pressed", String(isDark));
        themeToggle.setAttribute("aria-label", label);
        themeToggle.setAttribute("title", label);
    }

    syncThemeToggle(getActiveTheme());

    if (themeToggle) {
        themeToggle.addEventListener("click", function () {
            const nextTheme = getActiveTheme() === "dark" ? "light" : "dark";
            document.documentElement.setAttribute("data-theme", nextTheme);
            try {
                localStorage.setItem("theme", nextTheme);
            } catch (e) {
                // Ignore storage errors in restricted environments
            }
            syncThemeToggle(nextTheme);
        });
    }

    const handleSystemThemeChange = function () {
        if (!document.documentElement.hasAttribute("data-theme")) {
            syncThemeToggle(getActiveTheme());
        }
    };

    if (typeof colorSchemeQuery.addEventListener === "function") {
        colorSchemeQuery.addEventListener("change", handleSystemThemeChange);
    } else if (typeof colorSchemeQuery.addListener === "function") {
        colorSchemeQuery.addListener(handleSystemThemeChange);
    }

    const levelBars = document.querySelectorAll(".level-bar-inner[data-level]");
    const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    if (prefersReducedMotion || !("IntersectionObserver" in window)) {
        return;
    }

    levelBars.forEach((bar) => {
        bar.style.width = "0";
        bar.style.transition = "width 0.8s ease-out";
    });

    const observer = new IntersectionObserver(
        (entries, obs) => {
            entries.forEach((entry) => {
                if (entry.isIntersecting) {
                    const bar = entry.target;
                    bar.style.width = bar.dataset.level;
                    obs.unobserve(bar);
                }
            });
        },
        {
            threshold: 0.25,
        }
    );

    levelBars.forEach((bar) => {
        observer.observe(bar);
    });

    window.addEventListener("beforeprint", () => {
        levelBars.forEach((bar) => {
            bar.style.width = bar.dataset.level;
        });
    });
});
