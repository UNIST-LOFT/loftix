#!/usr/bin/env python3
"""Compute BB distances from call graph for SDFuzz directed fuzzing.

Uses the compiled binary's debug info to map BBs to functions,
then builds a function-level call graph from BBcalls.txt.

Input files (in dist_dir):
  BBtargets.txt  - target source locations
  BBnames.txt    - all basic blocks known to the instrumentation
  BBcalls.txt    - bb_name,called_function
  IIcalls.txt    - indirect call sites

Output:
  distance.cfg.txt - bb_name,distance for every BB
"""

import sys
import os
import re
import subprocess
from collections import defaultdict, deque


def load_bb_targets(path):
    """Load target BBs from BBtargets.txt.

    Handles two formats:
      Format A: function_name (filename:line)   -- from Stackparser.py
      Format B: filename:line                    -- raw format
    """
    targets = set()
    if not os.path.exists(path):
        return targets
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.endswith(':'):
                line = line[:-1]
            # Try to extract (filename:line) from "funcname (file:line)"
            m = re.search(r'\(([^()]+:\d+)\)', line)
            if m:
                targets.add(m.group(1))
            elif ':' in line:
                targets.add(line)
    return targets


def load_bb_names(path):
    """Load all BB identifiers from BBnames.txt (filename:line per line)."""
    names = set()
    if not os.path.exists(path):
        return names
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if ':' in line:
                names.add(line)
    return names


def load_bb_calls(path):
    """Load BBcalls.txt: bb_name,called_function per line."""
    calls = defaultdict(set)
    if not os.path.exists(path):
        return calls
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split(',', 1)
            if len(parts) == 2:
                bb, func = parts
                bb = bb.strip()
                func = func.strip()
                if ':' in bb and func:
                    calls[bb].add(func)
    return calls


def load_ii_calls(path):
    """Load IIcalls.txt: indirect call sites.

    Format per line: <filename>,<line> <function_name>
    Example: conftest.c,55 f

    Returns list of (call_site_loc, function_name) tuples.
    """
    calls = []
    if not os.path.exists(path):
        return calls
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            pos = line.rfind(' ')
            if pos < 0:
                continue
            call_site = line[:pos].strip()
            func_name = line[pos + 1:].strip()
            if not call_site or not func_name:
                continue
            if func_name.startswith('llvm.'):
                continue
            if ',' not in call_site:
                continue
            calls.append((call_site, func_name))
    return calls


def build_func_map_from_binary(binary_path):
    """Use nm and addr2line to map (file, line) -> function name.

    Returns:
      func_ranges: dict filename -> list of (start_line, end_line, func_name)
      func_addrs: dict func_name -> (start_addr, end_addr)
      func_locations: dict func_name -> (file, line)
    """
    try:
        result = subprocess.run(
            ['nm', '-n', binary_path],
            capture_output=True, text=True, timeout=30)
        nm_lines = result.stdout.strip().split('\n')
    except Exception as e:
        print("[dist] nm failed: {}".format(e))
        return {}, {}, {}

    func_syms = []
    for line in nm_lines:
        parts = line.split()
        if len(parts) >= 3 and parts[1] in ('T', 't', 'W', 'w'):
            try:
                addr = int(parts[0], 16)
                name = parts[2]
                func_syms.append((addr, name))
            except ValueError:
                continue

    if not func_syms:
        print("[dist] No function symbols found")
        return {}, {}, {}

    func_addrs = {}
    for i, (addr, name) in enumerate(func_syms):
        if i + 1 < len(func_syms):
            end = func_syms[i + 1][0]
        else:
            end = addr + 0x10000
        func_addrs[name] = (addr, end)

    func_locations = {}
    batch_size = 500

    for batch_start in range(0, len(func_syms), batch_size):
        batch = func_syms[batch_start:batch_start + batch_size]
        addrs = ['0x{:x}'.format(addr) for addr, _ in batch]

        try:
            result = subprocess.run(
                ['addr2line', '-e', binary_path, '-f', '-i'] + addrs,
                capture_output=True, text=True, timeout=60)
            lines = result.stdout.strip().split('\n')
        except Exception as e:
            print("[dist] addr2line failed: {}".format(e))
            continue

        for j in range(0, len(lines) - 1, 2):
            if j // 2 >= len(batch):
                break
            location = lines[j + 1].strip()
            orig_name = batch[j // 2][1]

            if ':' in location and location != '??:?':
                file_part, line_part = location.rsplit(':', 1)
                try:
                    line_num = int(line_part)
                    file_name = os.path.basename(file_part)
                    func_locations[orig_name] = (file_name, line_num)
                except ValueError:
                    pass

    print("[dist] Mapped {} functions to source locations".format(
        len(func_locations)))

    func_ranges = defaultdict(list)
    for name, (file_name, line_num) in func_locations.items():
        if name in func_addrs:
            func_ranges[file_name].append((line_num, name, func_addrs[name]))

    for file_name in func_ranges:
        entries = sorted(func_ranges[file_name], key=lambda x: x[0])
        func_ranges[file_name] = entries

    return func_ranges, func_addrs, func_locations


def bb_to_function(filename, line_num, func_ranges, func_locations):
    """Map a BB's file:line to its containing function name."""
    candidates = [filename]
    for prefix in ('bfd/', 'binutils/', 'opcodes/', 'libiberty/'):
        candidates.append(prefix + filename)

    for relname in candidates:
        if relname not in func_ranges:
            continue
        entries = func_ranges[relname]
        best = None
        for start, name, addrs in entries:
            if start <= line_num:
                best = name
            else:
                break
        if best:
            return best

    for name, (f, l) in func_locations.items():
        if f == filename and abs(l - line_num) < 50:
            return name

    return None


def main():
    if len(sys.argv) < 3:
        print("Usage: {} <dist_dir> <output_file> [binary_path]".format(sys.argv[0]))
        sys.exit(1)

    dist_dir = sys.argv[1]
    output_file = sys.argv[2]

    target_bbs = load_bb_targets(os.path.join(dist_dir, "BBtargets.txt"))
    bb_names = load_bb_names(os.path.join(dist_dir, "BBnames.txt"))
    bb_calls = load_bb_calls(os.path.join(dist_dir, "BBcalls.txt"))

    if len(sys.argv) >= 4:
        binary_path = sys.argv[3]
        if not os.path.isfile(binary_path):
            print("[dist] ERROR: Provided binary not found: {}".format(binary_path))
            sys.exit(1)
    else:
        work_dir = os.path.dirname(dist_dir)
        binary_path = None
        for candidate in [
            os.path.join(work_dir, 'build-pass1', 'binutils', 'nm-new'),
            os.path.join(work_dir, 'build', 'binutils', 'nm-new'),
            os.path.join(work_dir, 'build', 'binutils', '.libs', 'nm-new'),
            os.path.join(work_dir, 'nm'),
        ]:
            if os.path.isfile(candidate):
                binary_path = candidate
                break

    if not binary_path:
        print("[dist] ERROR: Cannot find compiled binary")
        sys.exit(1)

    print("[dist] Binary: {}".format(binary_path))
    print("[dist] Loaded {} targets".format(len(target_bbs)))
    print("[dist] Loaded {} BB names (all BBs)".format(len(bb_names)))
    print("[dist] Loaded {} direct call entries".format(len(bb_calls)))

    ii_calls = load_ii_calls(os.path.join(dist_dir, "IIcalls.txt"))
    print("[dist] Loaded {} indirect call entries".format(len(ii_calls)))

    # Build function map from binary debug info
    print("[dist] Building function map from binary debug info...")
    func_ranges, func_addrs, func_locations = build_func_map_from_binary(binary_path)

    # ----- Build function-level call graph -----
    func_graph = defaultdict(set)

    # Direct calls from BBcalls.txt
    direct_edges = 0
    for bb, called_funcs in bb_calls.items():
        if ':' not in bb:
            continue
        filename, line_str = bb.rsplit(':', 1)
        try:
            line_num = int(line_str)
        except ValueError:
            continue
        caller_func = bb_to_function(filename, line_num, func_ranges, func_locations)
        if caller_func is None:
            caller_func = filename + ":unknown"
        for callee in called_funcs:
            func_graph[caller_func].add(callee)
            direct_edges += 1
    print("[dist] Direct call edges in func_graph: {}".format(direct_edges))

    # Indirect calls from IIcalls.txt
    ii_matched = 0
    ii_unmatched = 0
    for call_site, func_name in ii_calls:
        pos = call_site.rfind(',')
        if pos < 0:
            ii_unmatched += 1
            continue
        filename = call_site[:pos].strip()
        try:
            line_num = int(call_site[pos + 1:].strip())
        except ValueError:
            ii_unmatched += 1
            continue
        if not filename:
            ii_unmatched += 1
            continue
        caller_func = bb_to_function(filename, line_num, func_ranges, func_locations)
        if caller_func is None:
            caller_func = filename + ":unknown"
        func_graph[caller_func].add(func_name)
        ii_matched += 1
    if ii_calls:
        print("[dist] Indirect calls: {} mapped, {} unmatched".format(
            ii_matched, ii_unmatched))

    # ----- Map targets to functions -----
    target_funcs = set()
    for tbb in target_bbs:
        if ':' not in tbb:
            continue
        filename, line_str = tbb.rsplit(':', 1)
        try:
            line_num = int(line_str)
        except ValueError:
            continue
        fname = bb_to_function(filename, line_num, func_ranges, func_locations)
        if fname:
            target_funcs.add(fname)
            print("[dist] Target {} -> function {}".format(tbb, fname))
        else:
            target_funcs.add(filename + ":unknown")
            print("[dist] Target {} -> function {} (fallback)".format(
                tbb, filename + ":unknown"))
    print("[dist] {} target functions identified".format(len(target_funcs)))

    # ----- BFS from targets on reverse call graph -----
    rev_graph = defaultdict(set)
    for caller, callees in func_graph.items():
        for callee in callees:
            rev_graph[callee].add(caller)

    func_dist = {}
    queue = deque()
    for tf in target_funcs:
        if tf not in func_dist:
            func_dist[tf] = 0
            queue.append(tf)

    while queue:
        func = queue.popleft()
        dist = func_dist[func]
        for caller in rev_graph.get(func, []):
            if caller not in func_dist:
                func_dist[caller] = dist + 1
                queue.append(caller)

    print("[dist] BFS reached {} functions".format(len(func_dist)))
    if func_dist:
        print("[dist] Max distance: {}".format(max(func_dist.values())))
        for fn, d in sorted(func_dist.items(), key=lambda x: x[1])[:20]:
            print("  dist {}: {}".format(d, fn))

    # ----- Assign distances to all BBs from BBnames.txt -----
    bb_distances = {}
    matched = 0
    no_func = 0
    not_in_graph = 0

    # Also keep track of which BBs are targets (distance 0)
    target_bbs_stripped = set()
    for tbb in target_bbs:
        if ':' in tbb:
            target_bbs_stripped.add(tbb)

    for bb in bb_names:
        if bb in target_bbs:
            bb_distances[bb] = 0
            matched += 1
            continue

        filename, line_str = bb.rsplit(':', 1)
        try:
            line_num = int(line_str)
        except ValueError:
            bb_distances[bb] = 9999
            not_in_graph += 1
            continue

        fname = bb_to_function(filename, line_num, func_ranges, func_locations)
        if fname is None:
            bb_distances[bb] = 9999
            no_func += 1
            continue

        if fname in func_dist:
            bb_distances[bb] = func_dist[fname]
            matched += 1
        else:
            bb_distances[bb] = 9999
            not_in_graph += 1

    print("[dist] Distances assigned: {} BBs in target functions -- {} BBs no func match -- {} BBs not in call graph".format(
        sum(1 for d in bb_distances.values() if d == 0),
        no_func, not_in_graph))

    # Write distance.cfg.txt
    with open(output_file, 'w') as f:
        for bb, dist in sorted(bb_distances.items()):
            f.write("{},{}\n".format(bb, dist))

    # Stats
    if bb_distances:
        reachable = sum(1 for d in bb_distances.values() if 0 < d < 9999)
        unreachable = sum(1 for d in bb_distances.values() if d == 9999)
        at_target = sum(1 for d in bb_distances.values() if d == 0)
        print("[dist] Wrote {} BB distances to {}".format(
            len(bb_distances), output_file))
        print("[dist] At target: {}, Reachable: {}, Unreachable: {}".format(
            at_target, reachable, unreachable))
    else:
        print("[dist] WARNING: No distances computed!")


if __name__ == "__main__":
    main()
