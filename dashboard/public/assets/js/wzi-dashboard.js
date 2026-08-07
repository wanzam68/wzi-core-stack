"use strict";

(function () {
    const clock = document.getElementById("utc-clock");

    function updateClock() {
        if (!clock) {
            return;
        }

        const now = new Date();

        clock.textContent =
            "UTC " +
            now.toLocaleTimeString("en-GB", {
                timeZone: "UTC",
                hour12: false
            });
    }

    updateClock();
    window.setInterval(updateClock, 1000);

    const links = document.querySelectorAll(".sidebar a");

    links.forEach(function (link) {
        link.addEventListener("click", function () {
            links.forEach(function (item) {
                item.classList.remove("active");
            });

            link.classList.add("active");
        });
    });
})();
