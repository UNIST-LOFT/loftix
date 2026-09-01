#!/usr/bin/env python3
"""Compute BB distances from call graph for SDFuzz directed fuzzing.

Uses the compiled binary's debug info to map BBs to functions,
then builds a function-level call graph from BBcalls.txt.

Input files (in dist_dir):
  BBtargets.txt  - target source locations (file:line)
  BBcalls.txt    - bb_name,called_function

Output:
  distance.cfg.txt - bb_name,distance for every BB
"""

import sys
import os
import re
import subprocess
from collections import defaultdict, deque


def load_bb_targets(path):
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
            if ':' in line:
                targets.add(line)
    return targets


def load_bb_calls(path):
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


def build_func_map_from_binary(binary_path):
    """Use nm and addr2line to map (file, line) -> function name.

    Returns:
      func_ranges: dict filename -> list of (start_line, end_line, func_name)
      func_addrs: dict func_name -> (start_addr, end_addr)
    """
    # Get sorted function symbols
    try:
        result = subprocess.run(
            ['nm', '-n', binary_path],
            capture_output=True, text=True, timeout=30)
        nm_lines = result.stdout.strip().split('\n')
    except Exception as e:
        print("[dist] nm failed: {}".format(e))
        return {}, {}

    # Parse nm output: address type name
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
        return {}, {}

    # Compute function end addresses (next function's start)
    func_addrs = {}
    for i, (addr, name) in enumerate(func_syms):
        if i + 1 < len(func_syms):
            end = func_syms[i + 1][0]
        else:
            end = addr + 0x10000  # arbitrary large end
        func_addrs[name] = (addr, end)

    # Use addr2line to map function start addresses to source locations
    # Process in batches to avoid too many subprocess calls
    func_locations = {}  # func_name -> (file, line)
    batch_size = 500

    for batch_start in range(0, len(func_syms), batch_size):
        batch = func_syms[batch_start:batch_start + batch_size]
        # Create input for addr2line: one address per line
        addrs = ['0x{:x}'.format(addr) for addr, _ in batch]

        try:
            result = subprocess.run(
                ['addr2line', '-e', binary_path, '-f', '-i'] + addrs,
                capture_output=True, text=True, timeout=60)
            lines = result.stdout.strip().split('\n')
        except Exception as e:
            print("[dist] addr2line failed: {}".format(e))
            continue

        # addr2line output: function_name\nfile:line\n (pairs)
        for j in range(0, len(lines) - 1, 2):
            func_name_out = lines[j].strip()
            location = lines[j + 1].strip()
            orig_name = batch[j // 2][1]

            if ':' in location and location != '??:?':
                file_part, line_part = location.rsplit(':', 1)
                try:
                    line_num = int(line_part)
                    # Extract just the filename
                    file_name = os.path.basename(file_part)
                    func_locations[orig_name] = (file_name, line_num)
                except ValueError:
                    pass

    print("[dist] Mapped {} functions to source locations".format(
        len(func_locations)))

    # Build func_ranges from func_locations and func_addrs
    func_ranges = defaultdict(list)
    for name, (file_name, line_num) in func_locations.items():
        if name in func_addrs:
            # We use address range to determine "end line" later
            func_ranges[file_name].append((line_num, name, func_addrs[name]))

    # Sort and compute end lines based on next function in same file
    for file_name in func_ranges:
        entries = sorted(func_ranges[file_name], key=lambda x: x[0])
        func_ranges[file_name] = entries

    return func_ranges, func_addrs, func_locations


def bb_to_function(filename, line_num, func_ranges, func_locations):
    """Map a BB's file:line to its containing function name."""
    # Try exact match first, then try with common prefixes
    candidates = [filename]
    for prefix in ('bfd/', 'binutils/', 'opcodes/', 'libiberty/'):
        candidates.append(prefix + filename)

    for relname in candidates:
        if relname not in func_ranges:
            continue
        entries = func_ranges[relname]
        # Binary search: find the function whose start_line <= line_num
        # and is the closest
        best = None
        for start, name, addrs in entries:
            if start <= line_num:
                best = name
            else:
                break
        if best:
            return best

    # Fallback: check func_locations for any function in the same file
    # with a matching prefix
    for name, (f, l) in func_locations.items():
        if f == filename and abs(l - line_num) < 50:
            return name

    return None


def main():
    if len(sys.argv) != 3:
        print("Usage: {} <dist_dir> <output_file>".format(sys.argv[0]))
        sys.exit(1)

    dist_dir = sys.argv[1]
    output_file = sys.argv[2]

    target_bbs = load_bb_targets(os.path.join(dist_dir, "BBtargets.txt"))
    bb_calls = load_bb_calls(os.path.join(dist_dir, "BBcalls.txt"))

    # Find the compiled binary
    work_dir = os.path.dirname(dist_dir)
    build_dir = os.path.join(work_dir, "build")
    binary_path = None
    for candidate in [
        os.path.join(build_dir, 'binutils', 'nm-new'),
        os.path.join(build_dir, 'binutils', '.libs', 'nm-new'),
        os.path.join(work_dir, 'nm'),
    ]:
        if os.path.isfile(candidate):
            binary_path = candidate
            break

    if not binary_path:
        print("[dist] ERROR: Cannot find compiled binary")
        sys.exit(1)

    print("[dist] Binary: {}".format(binary_path))
    print("[dist] Loaded {} target BBs".format(len(target_bbs)))
    print("[dist] Loaded {} BB call entries".format(len(bb_calls)))

    # Build function map from binary debug info
    print("[dist] Building function map from binary debug info...")
    func_ranges, func_addrs, func_locations = build_func_map_from_binary(binary_path)

    # Add target BBs to the set of all BBs
    all_bbs = set(bb_calls.keys())
    all_bbs.update(target_bbs)

    # Build function-level call graph
    func_graph = defaultdict(set)
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

    # Map target BBs to functions
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

    # Build reverse call graph: callee -> set of callers
    rev_graph = defaultdict(set)
    for caller, callees in func_graph.items():
        for callee in callees:
            rev_graph[callee].add(caller)

    # BFS from target functions on reverse call graph
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

    # Map BBs to functions and assign distances
    bb_distances = {}
    matched = 0
    unmatched = 0
    for bb in all_bbs:
        if bb in target_bbs:
            bb_distances[bb] = 0
            matched += 1
            continue

        if ':' not in bb:
            bb_distances[bb] = 9999
            unmatched += 1
            continue

        filename, line_str = bb.rsplit(':', 1)
        try:
            line_num = int(line_str)
        except ValueError:
            bb_distances[bb] = 9999
            unmatched += 1
            continue

        fname = bb_to_function(filename, line_num, func_ranges, func_locations)
        if fname and fname in func_dist:
            bb_distances[bb] = func_dist[fname]
            matched += 1
        else:
            bb_distances[bb] = 9999
            unmatched += 1

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
        print("[dist] At target: {}, Reachable: {}, Unreachable: {}, Matched: {}".format(
            at_target, reachable, unreachable, matched))

        if func_dist:
            print("[dist] Function distances from target:")
            for fn, d in sorted(func_dist.items(), key=lambda x: x[1])[:20]:
                print("  {}: {}".format(fn, d))
    else:
        print("[dist] WARNING: No distances computed!")


if __name__ == "__main__":
    main()
