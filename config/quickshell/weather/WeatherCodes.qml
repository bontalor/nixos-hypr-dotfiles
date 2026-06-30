pragma Singleton

import QtQuick
import Quickshell

// Static lookup table mapping wttr.in weather codes (integers) to
// { icon, desc }. Pure data singleton — no services, no state.

Singleton {
    // 48-entry wttr.in code table. Icons are emoji rendered via the
    // system emoji font (consistent with wttr.in's own UI).
    readonly property var codes: ({
        113: { icon: "\u2600\uFE0F", desc: "Sunny" },
        116: { icon: "\u26C5",       desc: "Partly cloudy" },
        119: { icon: "\u2601",       desc: "Cloudy" },
        122: { icon: "\u2601",       desc: "Overcast" },
        143: { icon: "\u{1F32B}",    desc: "Mist" },
        176: { icon: "\u{1F326}",    desc: "Patchy rain possible" },
        179: { icon: "\u{1F328}",    desc: "Patchy snow possible" },
        182: { icon: "\u{1F328}",    desc: "Patchy sleet possible" },
        185: { icon: "\u{1F328}",    desc: "Patchy freezing drizzle possible" },
        200: { icon: "\u26C8",       desc: "Thundery outbreaks possible" },
        227: { icon: "\u{1F328}",    desc: "Blowing snow" },
        230: { icon: "\u{1F328}",    desc: "Blizzard" },
        248: { icon: "\u{1F32B}",    desc: "Fog" },
        260: { icon: "\u{1F32B}",    desc: "Freezing fog" },
        263: { icon: "\u{1F326}",    desc: "Patchy light drizzle" },
        266: { icon: "\u{1F326}",    desc: "Light drizzle" },
        281: { icon: "\u{1F328}",    desc: "Freezing drizzle" },
        284: { icon: "\u{1F328}",    desc: "Heavy freezing drizzle" },
        293: { icon: "\u{1F326}",    desc: "Patchy light rain" },
        296: { icon: "\u{1F326}",    desc: "Light rain" },
        299: { icon: "\u{1F327}",    desc: "Moderate rain at times" },
        302: { icon: "\u{1F327}",    desc: "Moderate rain" },
        305: { icon: "\u{1F327}",    desc: "Heavy rain at times" },
        308: { icon: "\u{1F327}",    desc: "Heavy rain" },
        311: { icon: "\u{1F327}",    desc: "Light freezing rain" },
        314: { icon: "\u{1F327}",    desc: "Moderate or heavy freezing rain" },
        317: { icon: "\u{1F328}",    desc: "Light sleet" },
        320: { icon: "\u{1F328}",    desc: "Moderate or heavy sleet" },
        323: { icon: "\u{1F328}",    desc: "Patchy light snow" },
        326: { icon: "\u{1F328}",    desc: "Patchy moderate snow" },
        329: { icon: "\u{1F328}",    desc: "Patchy heavy snow" },
        332: { icon: "\u{1F328}",    desc: "Light snow" },
        335: { icon: "\u{1F328}",    desc: "Patchy heavy snow" },
        338: { icon: "\u{1F328}",    desc: "Moderate snow" },
        350: { icon: "\u{1F328}",    desc: "Light sleet showers" },
        353: { icon: "\u{1F326}",    desc: "Light rain showers" },
        356: { icon: "\u{1F327}",    desc: "Moderate or heavy rain showers" },
        359: { icon: "\u{1F327}",    desc: "Torrential rain shower" },
        362: { icon: "\u{1F328}",    desc: "Light sleet showers" },
        365: { icon: "\u{1F328}",    desc: "Moderate or heavy sleet showers" },
        368: { icon: "\u{1F328}",    desc: "Light snow showers" },
        371: { icon: "\u{1F328}",    desc: "Moderate or heavy snow showers" },
        374: { icon: "\u{1F328}",    desc: "Light showers of ice pellets" },
        377: { icon: "\u{1F328}",    desc: "Moderate or heavy showers of ice pellets" },
        386: { icon: "\u26C8",       desc: "Patchy light rain in area with thunder" },
        389: { icon: "\u26C8",       desc: "Moderate or heavy rain in area with thunder" },
        392: { icon: "\u26C8",       desc: "Patchy light snow in area with thunder" },
        395: { icon: "\u26C8",       desc: "Moderate or heavy snow in area with thunder" }
    })

    function icon(code) { return (codes[code] || {}).icon || "\u2600\uFE0F" }
    function desc(code) { return (codes[code] || {}).desc || "Unknown" }
}
