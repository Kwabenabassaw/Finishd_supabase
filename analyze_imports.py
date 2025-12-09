import os
import re

# Logic to map imports to file paths
def resolve_import(current_file_path, import_string, lib_root, package_name):
    # Handle package imports
    if import_string.startswith(f'package:{package_name}/'):
        relative_path = import_string[len(f'package:{package_name}/'):]
        return os.path.normpath(os.path.join(lib_root, relative_path))
    
    # Handle relative imports
    elif not import_string.startswith('package:') and not import_string.startswith('dart:'):
        current_dir = os.path.dirname(current_file_path)
        return os.path.normpath(os.path.join(current_dir, import_string))
    
    return None

def find_dart_files(root_dir):
    dart_files = []
    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.endswith('.dart'):
                dart_files.append(os.path.normpath(os.path.join(dirpath, filename)))
    return dart_files

def parse_imports(file_path, lib_root, package_name):
    imports = set()
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            # Match imports
            import_matches = re.findall(r"import\s+['\"]([^'\"]+)['\"]", content)
            for match in import_matches:
                resolved = resolve_import(file_path, match, lib_root, package_name)
                if resolved:
                    imports.add(resolved)
            
            # Match parts
            part_matches = re.findall(r"part\s+['\"]([^'\"]+)['\"]", content)
            for match in part_matches:
                 resolved = resolve_import(file_path, match, lib_root, package_name)
                 if resolved:
                     imports.add(resolved)
                     
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
    return imports

def main():
    lib_root = r'c:\Users\Kobby\Desktop\Finishd\finishd\lib'
    package_name = 'finishd'
    
    # 1. Find all dart files
    all_files = set(find_dart_files(lib_root))
    print(f"Total Dart files found: {len(all_files)}")
    
    # 2. Build Graph
    graph = {}
    for file_path in all_files:
        graph[file_path] = parse_imports(file_path, lib_root, package_name)
        
    # 3. Identify Entry Points (Roots)
    # Start with main.dart
    roots = {os.path.normpath(os.path.join(lib_root, 'main.dart'))}
    
    # Checking for files in lib/generated_plugin_registrant.dart if it exists (standard flutter)
    generated = os.path.normpath(os.path.join(lib_root, 'generated_plugin_registrant.dart'))
    if generated in all_files:
        roots.add(generated)

    # Validate roots exist
    valid_roots = {r for r in roots if r in all_files}
    if not valid_roots:
        print("Warning: main.dart not found in lib!")
        # Fallback? No, just list all
    else:
        print(f"Entry points: {[os.path.basename(r) for r in valid_roots]}")

    # 4. Traverse
    visited = set()
    queue = list(valid_roots)
    visited.update(valid_roots)
    
    while queue:
        current = queue.pop(0)
        neighbors = graph.get(current, set())
        for neighbor in neighbors:
            # Only care if neighbor is in our project (all_files)
            if neighbor in all_files and neighbor not in visited:
                visited.add(neighbor)
                queue.append(neighbor)
    
    # 5. Result
    unused = all_files - visited
    
    with open('analysis_results.txt', 'w', encoding='utf-8') as f:
        f.write(f"Total Dart files found: {len(all_files)}\n")
        f.write(f"Reachable files: {len(visited)}\n")
        f.write(f"Unused files: {len(unused)}\n\n")
        f.write("--- Unused Files ---\n")
        for file_path in sorted(unused):
            f.write(f"{os.path.relpath(file_path, lib_root)}\n")
        
        f.write("\n--- Used Files ---\n")
        for file_path in sorted(visited):
            f.write(f"{os.path.relpath(file_path, lib_root)}\n")

    print("Analysis complete. Results written to analysis_results.txt")


if __name__ == '__main__':
    main()
