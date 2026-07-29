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
        113: { icon: "☀️",             desc: "Sunny" },                 // ☀️
        116: { icon: "⛅",                   desc: "Partly cloudy" },         // ⛅
        119: { icon: "\u{1F325}️",          desc: "Cloudy" },                // 🌥️
        122: { icon: "☁️",             desc: "Overcast" },              // ☁️

        // Mist / fog
        143: { icon: "\u{1F32B}️",          desc: "Mist" },                  // 🌫️
        248: { icon: "\u{1F32B}️",          desc: "Fog" },                   // 🌫️
        260: { icon: "\u{1F32B}️",          desc: "Freezing fog" },          // 🌫️

        // Drizzle
        185: { icon: "\u{1F326}️",          desc: "Patchy freezing drizzle possible" },  // 🌦️
        263: { icon: "\u{1F326}️",          desc: "Patchy light drizzle" },              // 🌦️
        266: { icon: "\u{1F326}️",          desc: "Light drizzle" },                     // 🌦️
        281: { icon: "\u{1F327}️",          desc: "Freezing drizzle" },                  // 🌧️
        284: { icon: "\u{1F327}️",          desc: "Heavy freezing drizzle" },            // 🌧️

        // Rain
        176: { icon: "\u{1F326}️",          desc: "Patchy rain possible" },              // 🌦️
        293: { icon: "\u{1F326}️",          desc: "Patchy light rain" },                 // 🌦️
        296: { icon: "\u{1F326}️",          desc: "Light rain" },                        // 🌦️
        299: { icon: "\u{1F327}️",          desc: "Moderate rain at times" },            // 🌧️
        302: { icon: "\u{1F327}️",          desc: "Moderate rain" },                     // 🌧️
        305: { icon: "\u{1F327}️",          desc: "Heavy rain at times" },               // 🌧️
        308: { icon: "\u{1F327}️",          desc: "Heavy rain" },                        // 🌧️
        353: { icon: "\u{1F326}️",          desc: "Light rain showers" },                // 🌦️
        356: { icon: "\u{1F327}️",          desc: "Moderate or heavy rain showers" },    // 🌧️
        359: { icon: "\u{1F327}️",          desc: "Torrential rain shower" },            // 🌧️

        // Freezing rain / sleet
        311: { icon: "\u{1F327}️",          desc: "Light freezing rain" },               // 🌧️
        314: { icon: "\u{1F327}️",          desc: "Moderate or heavy freezing rain" },   // 🌧️
        317: { icon: "\u{1F328}️",          desc: "Light sleet" },                       // 🌨️
        320: { icon: "\u{1F328}️",          desc: "Moderate or heavy sleet" },           // 🌨️
        182: { icon: "\u{1F328}️",          desc: "Patchy sleet possible" },             // 🌨️
        350: { icon: "\u{1F328}️",          desc: "Light sleet showers" },               // 🌨️
        362: { icon: "\u{1F328}️",          desc: "Light sleet showers" },               // 🌨️
        365: { icon: "\u{1F328}️",          desc: "Moderate or heavy sleet showers" },   // 🌨️

        // Snow
        179: { icon: "\u{1F328}️",          desc: "Patchy snow possible" },              // 🌨️
        323: { icon: "\u{1F328}️",          desc: "Patchy light snow" },                 // 🌨️
        326: { icon: "\u{1F328}️",          desc: "Patchy moderate snow" },              // 🌨️
        329: { icon: "\u{1F328}️",          desc: "Patchy heavy snow" },                 // 🌨️
        332: { icon: "\u{1F328}️",          desc: "Light snow" },                        // 🌨️
        335: { icon: "\u{1F328}️",          desc: "Patchy heavy snow" },                 // 🌨️
        338: { icon: "\u{1F328}️",          desc: "Moderate snow" },                     // 🌨️
        368: { icon: "\u{1F328}️",          desc: "Light snow showers" },                // 🌨️
        371: { icon: "\u{1F328}️",          desc: "Moderate or heavy snow showers" },    // 🌨️
        227: { icon: "\u{1F32C}️",          desc: "Blowing snow" },                      // 🌬️
        230: { icon: "❄️",             desc: "Blizzard" },                          // ❄️

        // Ice pellets (no dedicated emoji — closest is snow cloud)
        374: { icon: "\u{1F328}️",          desc: "Light showers of ice pellets" },             // 🌨️
        377: { icon: "\u{1F328}️",          desc: "Moderate or heavy showers of ice pellets" }, // 🌨️

        // Thunder
        200: { icon: "\u{1F329}️",          desc: "Thundery outbreaks possible" },              // 🌩️
        386: { icon: "⛈️",             desc: "Patchy light rain in area with thunder" },   // ⛈️
        389: { icon: "⛈️",             desc: "Moderate or heavy rain in area with thunder" }, // ⛈️
        392: { icon: "⛈️",             desc: "Patchy light snow in area with thunder" },   // ⛈️
        395: { icon: "⛈️",             desc: "Moderate or heavy snow in area with thunder" } // ⛈️
    })

    function icon(code) { return (codes[code] || {}).icon || "☀️" }
    function desc(code) { return (codes[code] || {}).desc || "Unknown" }
}
