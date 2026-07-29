pragma Singleton

import QtQuick
import Quickshell

// Static lookup table mapping wttr.in weather codes (integers) to
// { icon, desc }. Pure data singleton — no services, no state.
//
// All emoji use their fully-qualified sequences (with ️ where required)
// so they render in color rather than as monochrome text glyphs.

Singleton {
    readonly property var codes: ({
        // Clear / cloudy gradient
        113: { icon: "☀️",  desc: "Sunny" },
        116: { icon: "⛅",  desc: "Partly cloudy" },
        119: { icon: "🌥️",  desc: "Cloudy" },
        122: { icon: "☁️",  desc: "Overcast" },

        // Mist / fog
        143: { icon: "🌫️",  desc: "Mist" },
        248: { icon: "🌫️",  desc: "Fog" },
        260: { icon: "🌫️",  desc: "Freezing fog" },

        // Drizzle
        185: { icon: "🌦️",  desc: "Patchy freezing drizzle possible" },
        263: { icon: "🌦️",  desc: "Patchy light drizzle" },
        266: { icon: "🌦️",  desc: "Light drizzle" },
        281: { icon: "🌧️",  desc: "Freezing drizzle" },
        284: { icon: "🌧️",  desc: "Heavy freezing drizzle" },

        // Rain
        176: { icon: "🌦️",  desc: "Patchy rain possible" },
        293: { icon: "🌦️",  desc: "Patchy light rain" },
        296: { icon: "🌦️",  desc: "Light rain" },
        299: { icon: "🌧️",  desc: "Moderate rain at times" },
        302: { icon: "🌧️",  desc: "Moderate rain" },
        305: { icon: "🌧️",  desc: "Heavy rain at times" },
        308: { icon: "🌧️",  desc: "Heavy rain" },
        353: { icon: "🌦️",  desc: "Light rain showers" },
        356: { icon: "🌧️",  desc: "Moderate or heavy rain showers" },
        359: { icon: "🌧️",  desc: "Torrential rain shower" },

        // Freezing rain / sleet
        311: { icon: "🌧️",  desc: "Light freezing rain" },
        314: { icon: "🌧️",  desc: "Moderate or heavy freezing rain" },
        317: { icon: "🌨️",  desc: "Light sleet" },
        320: { icon: "🌨️",  desc: "Moderate or heavy sleet" },
        182: { icon: "🌨️",  desc: "Patchy sleet possible" },
        350: { icon: "🌨️",  desc: "Light sleet showers" },
        362: { icon: "🌨️",  desc: "Light sleet showers" },
        365: { icon: "🌨️",  desc: "Moderate or heavy sleet showers" },

        // Snow
        179: { icon: "🌨️",  desc: "Patchy snow possible" },
        323: { icon: "🌨️",  desc: "Patchy light snow" },
        326: { icon: "🌨️",  desc: "Patchy moderate snow" },
        329: { icon: "🌨️",  desc: "Patchy heavy snow" },
        332: { icon: "🌨️",  desc: "Light snow" },
        335: { icon: "🌨️",  desc: "Patchy heavy snow" },
        338: { icon: "🌨️",  desc: "Moderate snow" },
        368: { icon: "🌨️",  desc: "Light snow showers" },
        371: { icon: "🌨️",  desc: "Moderate or heavy snow showers" },
        227: { icon: "🌬️",  desc: "Blowing snow" },
        230: { icon: "❄️",  desc: "Blizzard" },

        // Ice pellets (no dedicated emoji — closest is snow cloud)
        374: { icon: "🌨️",  desc: "Light showers of ice pellets" },
        377: { icon: "🌨️",  desc: "Moderate or heavy showers of ice pellets" },

        // Thunder
        200: { icon: "🌩️",  desc: "Thundery outbreaks possible" },
        386: { icon: "⛈️",  desc: "Patchy light rain in area with thunder" },
        389: { icon: "⛈️",  desc: "Moderate or heavy rain in area with thunder" },
        392: { icon: "⛈️",  desc: "Patchy light snow in area with thunder" },
        395: { icon: "⛈️",  desc: "Moderate or heavy snow in area with thunder" }
    })

    function icon(code) { return (codes[code] || {}).icon || "❓" }
    function desc(code) { return (codes[code] || {}).desc || "Unknown" }
}
