#!/usr/bin/env python3
"""Compile an organic-history run into JSON the simulation viewer reads.

Inputs (a run directory produced by run_ai_game.py with --saveturns 1):
  - per-turn savegames  runs/<run>/*.sav.gz   -> map terrain, territory owner grid, cities
  - server_stdout.log                          -> per-turn mechanics state (pressure, regions,
                                                  mandate/crisis/collapse, steppe power, friction,
                                                  withering)
Plus the scenario save (for per-player RGB colours) and script.lua (for region boxes).

Outputs (under --out):
  - map.json       static: terrain grid, terrain palette, players+colours, region boxes
  - timeline.json  per-turn frames: owner grid, cities, per-civ stats, regions, city pressure,
                   mechanics events

Extends the INI idea in tools/organic_history/parse_savegame.py; adds the savegame vector
(c={...}) table parse that the lightweight parser skips.
"""
from __future__ import annotations

import argparse
import colorsys
import glob
import gzip
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

# ---------------------------------------------------------------- savegame I/O

def open_save(path: Path):
    p = str(path)
    if p.endswith(".gz"):
        return gzip.open(path, "rt", encoding="utf-8", errors="replace")
    return open(path, encoding="utf-8", errors="replace")


def split_csv(line: str) -> list[str]:
    """Split a freeciv savegame table row on commas, respecting double quotes."""
    out, cur, inq = [], [], False
    for ch in line:
        if ch == '"':
            inq = not inq
            cur.append(ch)
        elif ch == "," and not inq:
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    out.append("".join(cur))
    return out


def unquote(s: str) -> str:
    s = s.strip()
    if len(s) >= 2 and s[0] == '"' and s[-1] == '"':
        return s[1:-1]
    return s


def parse_save(path: Path, want_terrain: bool = False) -> dict:
    """Parse one savegame -> {turn, year, owner_rows, terrain_rows?, players{id:{...}}, cities[]}."""
    section = None
    cur_player = None
    out = {"players": {}, "cities": [], "owner": {}, "terrain": {}, "turn": None, "year": None}
    it = open_save(path)
    while True:
        raw = it.readline()
        if not raw:
            break
        s = raw.strip()
        if not s or s.startswith("#") or s.startswith(";"):
            continue
        if s.startswith("[") and s.endswith("]"):
            section = s[1:-1]
            m = re.match(r"player(\d+)$", section)
            cur_player = int(m.group(1)) if m else None
            continue
        # vector table header for cities: c={"col",...}
        if cur_player is not None and s.startswith("c={"):
            cols = [unquote(c) for c in split_csv(s[s.index("{") + 1:].rstrip("}"))]
            colidx = {c: i for i, c in enumerate(cols)}
            n = out["players"].get(cur_player, {}).get("ncities", 0)
            for _ in range(n):
                row = it.readline()
                if not row:
                    break
                vals = split_csv(row.strip())

                def g(col):
                    i = colidx.get(col)
                    return vals[i] if i is not None and i < len(vals) else None

                try:
                    out["cities"].append({
                        "x": int(g("x")), "y": int(g("y")), "id": int(g("id")),
                        "size": int(g("size")), "name": unquote(g("name") or ""),
                        "owner": cur_player,
                        "capital": unquote(g("capital") or "Not") != "Not",
                    })
                except (TypeError, ValueError):
                    pass
            continue
        if "=" not in s:
            continue
        key, val = s.split("=", 1)
        key = key.strip()
        if section == "game" and key == "turn":
            out["turn"] = _toint(val)
        elif section == "game" and key == "year":
            out["year"] = _toint(val)
        elif section == "map" and re.match(r"t\d+$", key):
            if want_terrain:
                out["terrain"][int(key[1:])] = unquote(val)
        elif section == "map" and re.match(r"owner\d+$", key):
            out["owner"][int(key[5:])] = unquote(val)
        elif cur_player is not None:
            p = out["players"].setdefault(cur_player, {})
            if key == "name":
                p["name"] = unquote(val)
            elif key == "nation":
                p["nation"] = unquote(val)
            elif key == "is_alive":
                p["alive"] = val.strip() == "TRUE"
            elif key == "ncities":
                p["ncities"] = _toint(val)
            elif key in ("color.r", "color.g", "color.b"):
                p[key] = _toint(val)
    return out


def _toint(v):
    try:
        return int(v.strip())
    except (ValueError, AttributeError):
        return None


def owner_rows(parsed: dict) -> list[str]:
    ys = sorted(parsed["owner"])
    return [parsed["owner"][y] for y in ys]


def terrain_rows(parsed: dict) -> list[str]:
    ys = sorted(parsed["terrain"])
    return [parsed["terrain"][y] for y in ys]


# ---------------------------------------------------------------- log parsing

FIELD_RE = re.compile(r'(\w+)=("[^"]*"|\S+)')


def parse_fields(rest: str) -> dict:
    d = {}
    for k, v in FIELD_RE.findall(rest):
        d[k] = unquote(v)
    return d


def fnum(d, k):
    v = d.get(k)
    if v is None:
        return None
    try:
        return float(v)
    except ValueError:
        return None


def parse_logs(stdout_path: Path) -> dict:
    """Return per-turn log state keyed by turn:
    {turn: {cityState:{id:{...}}, regions:{rid:{...}}, players:{pid:{...}},
            steppe:{...}, friction:[...], withering:[...]}}"""
    turns: dict[int, dict] = {}

    def slot(t):
        return turns.setdefault(int(t), {"cityState": {}, "regions": {}, "players": {},
                                         "steppe": None, "friction": [], "withering": []})

    if not stdout_path.exists():
        return turns
    with open(stdout_path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            i = line.find("organic_history_")
            if i < 0:
                continue
            rest = line[i:]
            sp = rest.find(" ")
            if sp < 0:
                continue
            event = rest[:sp]
            d = parse_fields(rest[sp + 1:])
            t = d.get("turn")
            if t is None:
                continue
            S = slot(t)
            if event == "organic_history_city_pressure":
                cid = d.get("city_id")
                if cid is not None:
                    S["cityState"][int(float(cid))] = {
                        "unrest": fnum(d, "unrest"), "development": fnum(d, "development"),
                        "migration": fnum(d, "migration_pressure"), "region": d.get("region"),
                        "owner": _toint(d.get("player", "")),
                    }
            elif event == "organic_history_region":
                S["regions"][d.get("region")] = {
                    "leader": _toint(d.get("leader", "")), "leader_share": fnum(d, "leader_share"),
                    "classification": d.get("classification"), "total_cities": _toint(d.get("total_cities", "")),
                }
            elif event == "organic_history_metric":
                p = S["players"].setdefault(_toint(d.get("player", "")), {})
                p.update({"gold": _toint(d.get("gold", "")), "government": d.get("government"),
                          "alive": d.get("alive") == "true", "cities": _toint(d.get("cities", "")),
                          "nation": d.get("nation")})
            elif event == "organic_history_collapse":
                pid = _toint(d.get("player", ""))
                if pid is not None:
                    p = S["players"].setdefault(pid, {})
                    p.update({"mandate": fnum(d, "mandate"), "crisis": fnum(d, "crisis"),
                              "collapse_risk": fnum(d, "collapse_risk"), "actor": d.get("actor")})
            elif event == "organic_history_state_capacity":
                pid = _toint(d.get("player", ""))
                if pid is not None:
                    S["players"].setdefault(pid, {})["status"] = d.get("status")
            elif event == "organic_history_steppe_confederacy":
                S["steppe"] = {"power": fnum(d, "power"), "window": fnum(d, "window"),
                               "fragility": fnum(d, "neighbor_fragility"), "actor": d.get("actor")}
            elif event == "organic_history_steppe_friction":
                S["friction"].append({"city": d.get("city"), "owner": _toint(d.get("target_owner", "")),
                                       "tax": fnum(d, "tax"), "region": d.get("region")})
            elif event == "organic_history_hinterland_withering":
                S["withering"].append({"city": d.get("city"), "action": d.get("action"),
                                       "region": d.get("region"), "actor": d.get("actor")})
    return turns


# ---------------------------------------------------------------- colours / regions

def palette(n: int) -> list[list[int]]:
    out = []
    for i in range(n):
        h = (i * 0.61803398875) % 1.0
        r, g, b = colorsys.hsv_to_rgb(h, 0.62, 0.95)
        out.append([int(r * 255), int(g * 255), int(b * 255)])
    return out


def scenario_colors(scenario: Path | None, max_pid: int) -> dict[int, list[int]]:
    colors = {}
    if scenario and scenario.exists():
        parsed = parse_save(scenario)
        for pid, p in parsed["players"].items():
            if "color.r" in p:
                colors[pid] = [p.get("color.r", 0), p.get("color.g", 0), p.get("color.b", 0)]
    fallback = palette(max_pid + 1)
    return {pid: colors.get(pid, fallback[pid % len(fallback)]) for pid in range(max_pid + 1)}


REGION_RE = re.compile(
    r'(\w+) = \{name = "([^"]+)", x_min = (\d+), x_max = (\d+), y_min = (\d+), y_max = (\d+)\}')


def region_boxes(script_lua: Path) -> list[dict]:
    if not script_lua.exists():
        return []
    text = script_lua.read_text(encoding="utf-8", errors="replace")
    seen, out = set(), []
    for m in REGION_RE.finditer(text):
        rid = m.group(1)
        if rid in seen:
            continue
        seen.add(rid)
        out.append({"id": rid, "name": m.group(2),
                    "x_min": int(m.group(3)), "x_max": int(m.group(4)),
                    "y_min": int(m.group(5)), "y_max": int(m.group(6))})
    return out


TERRAIN_COLORS = {
    " ": [40, 70, 120], ":": [30, 60, 110], "a": [235, 240, 245], "t": [150, 160, 140],
    "p": [200, 185, 130], "g": [120, 165, 90], "f": [60, 120, 70], "j": [40, 110, 60],
    "d": [225, 205, 130], "h": [160, 150, 110], "m": [120, 110, 100], "s": [110, 140, 110],
    "l": [120, 110, 100],
}

def _region_entry(rid, v, pts):
    e = dict(id=rid, **v)
    if pts:
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        e["cx"] = round(sum(xs) / len(xs), 1)
        e["cy"] = round(sum(ys) / len(ys), 1)
        e["n"] = len(pts)
    return e


# ---------------------------------------------------------------- main

def main() -> int:
    ap = argparse.ArgumentParser(description="Compile a run into viewer JSON.")
    ap.add_argument("--run-dir", type=Path, required=True)
    ap.add_argument("--scenario", type=Path,
                    default=ROOT / "data/organic_history/scenarios/earth_global_4000_v1.sav")
    ap.add_argument("--script", type=Path, default=ROOT / "data/organic_history/script.lua")
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args()

    run_dir = args.run_dir
    out_dir = args.out or (run_dir / "viewer")
    out_dir.mkdir(parents=True, exist_ok=True)

    saves = sorted(glob.glob(str(run_dir / "*.sav.gz")))
    if not saves:
        print(f"no savegames in {run_dir}")
        return 1
    print(f"parsing {len(saves)} savegames + logs ...")

    logs = parse_logs(run_dir / "server_stdout.log")

    frames = []
    terrain = None
    max_pid = 0
    players_meta = {}
    for i, sv in enumerate(saves):
        parsed = parse_save(Path(sv), want_terrain=(terrain is None))
        if terrain is None and parsed["terrain"]:
            terrain = terrain_rows(parsed)
        turn = parsed["turn"]
        if turn is None:
            continue
        for pid, p in parsed["players"].items():
            max_pid = max(max_pid, pid)
            if pid not in players_meta and p.get("name"):
                players_meta[pid] = {"id": pid, "name": p.get("name"), "nation": p.get("nation")}
        # name -> xy index for joining friction/withering (which only log a city name)
        name_xy = {c["name"]: (c["x"], c["y"]) for c in parsed["cities"]}
        L = logs.get(turn, {})
        cstate = L.get("cityState", {})

        # region positions, data-derived: centroid/bbox of the cities currently in each region
        region_pts: dict[str, list] = {}
        for c in parsed["cities"]:
            reg = cstate.get(c["id"], {}).get("region")
            if reg:
                region_pts.setdefault(reg, []).append((c["x"], c["y"]))

        def attach_xy(ev):
            xy = name_xy.get(ev.get("city"))
            if xy:
                ev = dict(ev, x=xy[0], y=xy[1])
            return ev

        # merge per-civ stats from logs onto save player list
        civ = []
        for pid in sorted(parsed["players"]):
            p = parsed["players"][pid]
            lp = L.get("players", {}).get(pid, {})
            civ.append({"id": pid, "name": p.get("name"), "alive": p.get("alive"),
                        "cities": p.get("ncities", 0), "gold": lp.get("gold"),
                        "mandate": lp.get("mandate"), "crisis": lp.get("crisis"),
                        "collapse_risk": lp.get("collapse_risk"), "status": lp.get("status"),
                        "actor": lp.get("actor")})
        frames.append({
            "turn": turn, "year": parsed["year"],
            "owner": owner_rows(parsed),
            "cities": parsed["cities"],
            "players": civ,
            "regions": [_region_entry(r, v, region_pts.get(r))
                        for r, v in L.get("regions", {}).items()],
            "cityState": {str(cid): cstate[cid] for cid in cstate},
            "events": {
                "steppe": L.get("steppe"),
                "friction": [attach_xy(e) for e in L.get("friction", [])],
                "withering": [attach_xy(e) for e in L.get("withering", [])],
            },
        })
        if (i + 1) % 25 == 0:
            print(f"  ... {i + 1}/{len(saves)} (turn {turn})")

    frames.sort(key=lambda f: f["turn"])
    colors = scenario_colors(args.scenario, max_pid)
    xsize = len(terrain[0]) if terrain else (len(frames[0]["owner"][0].split(",")) if frames else 0)
    ysize = len(terrain) if terrain else (len(frames[0]["owner"]) if frames else 0)

    map_json = {
        "xsize": xsize, "ysize": ysize,
        "terrain": terrain or [],
        "terrainColors": TERRAIN_COLORS,
        "players": [{"id": pid, "name": players_meta.get(pid, {}).get("name", f"p{pid}"),
                     "nation": players_meta.get(pid, {}).get("nation"),
                     "color": colors.get(pid, [180, 180, 180])} for pid in range(max_pid + 1)],
        "regions": region_boxes(args.script),
    }
    timeline_json = {"turns": [f["turn"] for f in frames], "frames": frames}

    (out_dir / "map.json").write_text(json.dumps(map_json), encoding="utf-8")
    (out_dir / "timeline.json").write_text(json.dumps(timeline_json), encoding="utf-8")
    # ship the viewer next to the data so the dir is self-serving
    viewer_src = Path(__file__).resolve().parent / "viewer.html"
    if viewer_src.exists():
        (out_dir / "index.html").write_text(viewer_src.read_text(encoding="utf-8"), encoding="utf-8")
    print(f"wrote {out_dir}/map.json ({xsize}x{ysize}, {len(map_json['players'])} players, "
          f"{len(map_json['regions'])} regions) and timeline.json ({len(frames)} frames)")
    print(f"view it:  (cd {out_dir} && python3 -m http.server 8765)   then open  http://localhost:8765/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
