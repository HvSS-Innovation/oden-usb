import {layers, namedFlavor} from "@protomaps/basemaps";
import fs from "fs";
// Skapar MapLibre-stilen "oden" för tileserver-gl ur Protomaps Basemap (tema light). Körs av render-map.sh i en node-container.
const style = {
  version: 8, name: "ODEN",
  glyphs: "{fontstack}/{range}.pbf",
  sprite: "{styleJsonFolder}/sprite",
  sources: { protomaps: { type: "vector", url: "pmtiles://{sweden}", attribution: "© OpenStreetMap" } },
  layers: layers("protomaps", namedFlavor("light"), { lang: process.env.MAP_LANG || "sv" })
};
fs.writeFileSync("/out/oden.json", JSON.stringify(style));
console.log("lager:", style.layers.length);
