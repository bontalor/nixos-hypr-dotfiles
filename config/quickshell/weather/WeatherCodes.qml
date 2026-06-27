pragma Singleton

import QtQuick

QtObject {
    id: root

    property var codes: ({
        113: { icon: "\u2600\uFE0F", desc: "Sunny" },
        116: { icon: "\u26c5\uFE0F", desc: "Partly cloudy" },
        119: { icon: "\u2601\uFE0F", desc: "Cloudy" },
        122: { icon: "\u2601\uFE0F", desc: "Overcast" },
        143: { icon: "\uD83C\uDF2B", desc: "Mist" },
        176: { icon: "\uD83C\uDF27\uFE0F", desc: "Patchy rain possible" },
        179: { icon: "\uD83C\uDF28\uFE0F", desc: "Patchy snow possible" },
        182: { icon: "\uD83C\uDF28\uFE0F", desc: "Patchy sleet possible" },
        185: { icon: "\uD83C\uDF27\uFE0F", desc: "Patchy freezing drizzle possible" },
        200: { icon: "\uD83C\uDF29\uFE0F", desc: "Thundery outbreaks possible" },
        227: { icon: "\uD83C\uDF28\uFE0F", desc: "Blowing snow" },
        230: { icon: "\uD83C\uDF28\uFE0F", desc: "Blizzard" },
        248: { icon: "\uD83C\uDF2B", desc: "Fog" },
        260: { icon: "\uD83C\uDF2B", desc: "Freezing fog" },
        263: { icon: "\uD83C\uDF27\uFE0F", desc: "Patchy light drizzle" },
        266: { icon: "\uD83C\uDF27\uFE0F", desc: "Light drizzle" },
        281: { icon: "\uD83C\uDF27\uFE0F", desc: "Freezing drizzle" },
        284: { icon: "\uD83C\uDF27\uFE0F", desc: "Heavy freezing drizzle" },
        293: { icon: "\uD83C\uDF27\uFE0F", desc: "Patchy light rain" },
        296: { icon: "\uD83C\uDF27\uFE0F", desc: "Light rain" },
        299: { icon: "\uD83C\uDF27\uFE0F", desc: "Moderate rain at times" },
        302: { icon: "\uD83C\uDF27\uFE0F", desc: "Moderate rain" },
        305: { icon: "\uD83C\uDF27\uFE0F", desc: "Heavy rain at times" },
        308: { icon: "\uD83C\uDF27\uFE0F", desc: "Heavy rain" },
        311: { icon: "\uD83C\uDF27\uFE0F", desc: "Light freezing rain" },
        314: { icon: "\uD83C\uDF27\uFE0F", desc: "Moderate or heavy freezing rain" },
        317: { icon: "\uD83C\uDF28\uFE0F", desc: "Light sleet" },
        320: { icon: "\uD83C\uDF28\uFE0F", desc: "Moderate or heavy sleet" },
        323: { icon: "\uD83C\uDF28\uFE0F", desc: "Patchy light snow" },
        326: { icon: "\uD83C\uDF28\uFE0F", desc: "Patchy moderate snow" },
        329: { icon: "\uD83C\uDF28\uFE0F", desc: "Patchy heavy snow" },
        332: { icon: "\uD83C\uDF28\uFE0F", desc: "Moderate snow" },
        335: { icon: "\uD83C\uDF28\uFE0F", desc: "Patchy moderate snow" },
        338: { icon: "\uD83C\uDF28\uFE0F", desc: "Heavy snow" },
        350: { icon: "\uD83E\uDDCA", desc: "Ice pellets" },
        353: { icon: "\uD83C\uDF27\uFE0F", desc: "Light rain shower" },
        356: { icon: "\uD83C\uDF27\uFE0F", desc: "Moderate or heavy rain shower" },
        359: { icon: "\uD83C\uDF27\uFE0F", desc: "Torrential rain shower" },
        362: { icon: "\uD83C\uDF28\uFE0F", desc: "Light sleet showers" },
        365: { icon: "\uD83C\uDF28\uFE0F", desc: "Moderate or heavy sleet showers" },
        368: { icon: "\uD83C\uDF28\uFE0F", desc: "Light snow showers" },
        371: { icon: "\uD83C\uDF28\uFE0F", desc: "Moderate or heavy snow showers" },
        374: { icon: "\uD83E\uDDCA", desc: "Light showers of ice pellets" },
        377: { icon: "\uD83E\uDDCA", desc: "Moderate or heavy showers of ice pellets" },
        386: { icon: "\u26C8\uFE0F", desc: "Patchy light rain with thunder" },
        389: { icon: "\u26C8\uFE0F", desc: "Moderate or heavy rain with thunder" },
        392: { icon: "\u26C8\uFE0F", desc: "Patchy light snow with thunder" },
        395: { icon: "\u26C8\uFE0F", desc: "Moderate or heavy snow with thunder" }
    })

    function icon(code) {
        return (codes[code] && codes[code].icon) || "\u2600\uFE0F"
    }

    function desc(code) {
        return (codes[code] && codes[code].desc) || "Unknown"
    }
}
