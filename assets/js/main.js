document.addEventListener("DOMContentLoaded", function () {
    // Initialize the width to 0 for all level-bar-inner elements
    const levelBars = document.querySelectorAll(".level-bar-inner");
    levelBars.forEach((bar) => {
        bar.style.width = "0";
    });

    // Animate bars after the DOM is fully loaded
    window.addEventListener("load", function () {
        levelBars.forEach((bar) => {
            try {
                const level = bar.dataset.level || "50%"; // Default to "50%" if missing
                bar.style.transition = "width 0.8s"; // Add animation with CSS transition
                bar.style.width = level;
            } catch (error) {
                console.error("Failed to animate level bar:", error);
            }
        });
    });
});