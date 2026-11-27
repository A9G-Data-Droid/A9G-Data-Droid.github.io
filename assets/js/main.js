document.addEventListener("DOMContentLoaded", function () {
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
