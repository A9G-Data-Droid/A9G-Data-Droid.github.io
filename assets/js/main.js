document.addEventListener("DOMContentLoaded", function () {
    const levelBars = document.querySelectorAll(".level-bar-inner");

    // Set initial styles: width = 0% for all bars
    levelBars.forEach((bar) => {
        bar.style.width = "0";
        bar.style.transition = "width 0.8s"; // Ensure animation transition is set
    });

    // Trigger when the element is observed
    const observer = new IntersectionObserver(
        (entries, observer) => {
            entries.forEach((entry) => {
                if (entry.isIntersecting) {
                    const bar = entry.target;
                    const level = bar.dataset.level || "50%";
                    bar.style.width = level;
                    observer.unobserve(bar);
                }
            });
        },
        {
            threshold: 0.25,
        }
    );

    // Observe each progress bar
    levelBars.forEach((bar) => {
        observer.observe(bar);
    });
});