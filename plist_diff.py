#!/usr/bin/env python3
import sys
import plistlib

def compare_values(v1, v2, path=""):
    changes = []
    if isinstance(v1, dict) and isinstance(v2, dict):
        keys = set(v1.keys()).union(set(v2.keys()))
        for key in sorted(keys):
            current_path = f"{path} -> {key}" if path else key
            if key not in v1:
                changes.append(f"+ added: {current_path} = {v2[key]}")
            elif key not in v2:
                changes.append(f"- removed: {current_path} = {v1[key]}")
            else:
                changes.extend(compare_values(v1[key], v2[key], current_path))
    elif isinstance(v1, list) and isinstance(v2, list):
        id_keys = ['BundlePath', 'Path', 'Comment', 'Base']
        id_key = next((k for k in id_keys if any(isinstance(x, dict) and k in x for x in v1 + v2)), None)
        
        if id_key:
            dict1 = {str(x.get(id_key)): x for x in v1 if isinstance(x, dict) and id_key in x}
            dict2 = {str(x.get(id_key)): x for x in v2 if isinstance(x, dict) and id_key in x}
            all_ids = set(dict1.keys()).union(set(dict2.keys()))
            for uid in sorted(all_ids):
                current_path = f"{path} -> [{id_key}: {uid}]"
                if uid not in dict1:
                    changes.append(f"+ added item: {current_path}")
                elif uid not in dict2:
                    changes.append(f"- removed item: {current_path}")
                else:
                    changes.extend(compare_values(dict1[uid], dict2[uid], current_path))
        else:
            if v1 != v2:
                changes.append(f"~ changed: {path}\n    old count: {len(v1)}, new count: {len(v2)}")
    elif v1 != v2:
        changes.append(f"~ changed: {path}\n    old: {v1}\n    new: {v2}")
    return changes

def main():
    if len(sys.argv) != 3:
        print("usage: python3 plist_diff.py <file1.plist> <file2.plist>")
        sys.exit(1)

    try:
        with open(sys.argv[1], 'rb') as f1, open(sys.argv[2], 'rb') as f2:
            p1 = plistlib.load(f1)
            p2 = plistlib.load(f2)
    except Exception as e:
        print(f"error loading plists: {e}")
        sys.exit(1)

    diffs = compare_values(p1, p2)
    if diffs:
        print("\n".join(diffs))
    else:
        print("no differences found between the two plists.")

if __name__ == "__main__":
    main()
