# Gloam-generated Tiny Swords runtime derivatives

The PNGs below are Gloam's exported, curated, or optimized runtime derivatives
of the Tiny Swords source pack. They intentionally live under `assets/generated`
so they cannot be mistaken for untouched official source assets. The folders are
separated by role so the runtime imports only what the game actually needs.

The pack is authored at native pixel scale. Animated PNG sheets are documented
in `scripts/tiny_swords_asset_config.gd`, including measured source dimensions,
cell dimensions, frame counts, anchors, and intended scale. The visual lab uses
that registry and nearest-neighbour filtering.

The official source-pack files remain under `TinySwords/` for reference. No live
`.gd`, `.tscn`, or `.tres` resource points at that external source directory.
