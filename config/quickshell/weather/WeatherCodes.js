var codes = {
    113: { icon: "\u2600\uFE0F", desc: "Sunny" },
    116: { icon: "\u26c5\uFE0F", desc: "Partly cloudy" },
    119: { icon: "\u2601\uFE0F", desc: "Cloudy" },
    122: { icon: "\u2601\uFE0F", desc: "Overcast" },
    143: { icon: "\uD83C\uDF2B", desc: "Mist" },
    176: { icon: "\u2614\uFE0F", desc: "Patchy rain possible" },
    179: { icon: "\u2744\uFE0F", desc: "Patchy snow possible" },
    182: { icon: "\u2744\uFE0F", desc: "Patchy sleet possible" },
    185: { icon: "\u2614\uFE0F", desc: "Patchy freezing drizzle possible" },
    200: { icon: "\u26A1\uFE0F", desc: "Thundery outbreaks possible" },
    227: { icon: "\u2744\uFE0F", desc: "Patchy snow possible" },
    230: { icon: "\u2744\uFE0F", desc: "Patchy moderate snow" },
    248: { icon: "\uD83C\uDF2B", desc: "Fog" },
    260: { icon: "\uD83C\uDF2B", desc: "Freezing fog" },
    263: { icon: "\u2614\uFE0F", desc: "Patchy light drizzle" },
    266: { icon: "\u2614\uFE0F", desc: "Light drizzle" },
    281: { icon: "\u2614\uFE0F", desc: "Freezing drizzle" },
    284: { icon: "\u2614\uFE0F", desc: "Heavy freezing drizzle" },
    293: { icon: "\u2614\uFE0F", desc: "Patchy light rain" },
    296: { icon: "\u2614\uFE0F", desc: "Light rain" },
    299: { icon: "\u2614\uFE0F", desc: "Moderate rain at times" },
    302: { icon: "\u2614\uFE0F", desc: "Moderate rain" },
    305: { icon: "\u2614\uFE0F", desc: "Heavy rain at times" },
    308: { icon: "\u2614\uFE0F", desc: "Heavy rain" },
    311: { icon: "\u2614\uFE0F", desc: "Light freezing rain" },
    314: { icon: "\u2614\uFE0F", desc: "Moderate or heavy freezing rain" },
    317: { icon: "\u2744\uFE0F", desc: "Light sleet" },
    320: { icon: "\u2744\uFE0F", desc: "Moderate or heavy sleet" },
    323: { icon: "\u2744\uFE0F", desc: "Patchy light snow" },
    326: { icon: "\u2744\uFE0F", desc: "Patchy moderate snow" },
    329: { icon: "\u2744\uFE0F", desc: "Patchy heavy snow" },
    332: { icon: "\u2744\uFE0F", desc: "Moderate snow" },
    335: { icon: "\u2744\uFE0F", desc: "Patchy moderate snow" },
    338: { icon: "\u2744\uFE0F", desc: "Heavy snow" },
    350: { icon: "\u2744\uFE0F", desc: "Ice pellets" },
    353: { icon: "\u2614\uFE0F", desc: "Light rain shower" },
    356: { icon: "\u2614\uFE0F", desc: "Moderate or heavy rain shower" },
    359: { icon: "\u2614\uFE0F", desc: "Torrential rain shower" },
    362: { icon: "\u2744\uFE0F", desc: "Light sleet showers" },
    365: { icon: "\u2744\uFE0F", desc: "Moderate or heavy sleet showers" },
    368: { icon: "\u2744\uFE0F", desc: "Light snow showers" },
    371: { icon: "\u2744\uFE0F", desc: "Moderate or heavy snow showers" },
    374: { icon: "\u2744\uFE0F", desc: "Light showers of ice pellets" },
    377: { icon: "\u2744\uFE0F", desc: "Moderate or heavy showers of ice pellets" },
    386: { icon: "\u26A1\uFE0F", desc: "Patchy light rain with thunder" },
    389: { icon: "\u26A1\uFE0F", desc: "Moderate or heavy rain with thunder" },
    392: { icon: "\u26A1\uFE0F", desc: "Patchy light snow with thunder" },
    395: { icon: "\u26A1\uFE0F", desc: "Moderate or heavy snow with thunder" }
}

function icon(code) {
    return codes[code]?.icon ?? "\u2600\uFE0F"
}

function desc(code) {
    return codes[code]?.desc ?? "Unknown"
}
