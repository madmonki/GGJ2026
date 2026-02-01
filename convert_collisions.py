import sys
import re
import os

def convert_tscn(file_path):
    with open(file_path, 'r') as f:
        lines = f.readlines()

    # 1. Parse SubResources
    # Format: [sub_resource type="ConvexPolygonShape3D" id="ConvexPolygonShape3D_l2tqr"]
    # points = PackedVector3Array(...)
    resources = {}
    current_res_id = None
    
    res_pattern = re.compile(r'\[sub_resource type="ConvexPolygonShape3D" id="([^"]+)"\]')
    points_pattern = re.compile(r'points = PackedVector3Array\((.*)\)')

    for i, line in enumerate(lines):
        res_match = res_pattern.search(line)
        if res_match:
            current_res_id = res_match.group(1)
            # Find points in subsequent lines (usually next line or same line)
            for j in range(i, i + 5):
                if j >= len(lines): break
                points_match = points_pattern.search(lines[j])
                if points_match:
                    points_str = points_match.group(1)
                    resources[current_res_id] = points_str
                    break

    # 2. Identify Nodes and their parents
    # format: [node name="CollisionShape3D" type="CollisionShape3D" parent="..."]
    # shape = SubResource("...")
    
    node_pattern = re.compile(r'\[node name="([^"]+)" type="CollisionShape3D" parent="([^"]+)"(.*)\]')
    unique_id_pattern = re.compile(r'unique_id=([0-9]+)')
    shape_ref_pattern = re.compile(r'shape = SubResource\("([^"]+)"\)')

    nodes_to_merge = {} # parent_path -> list of (node_lines_range, shape_id)
    
    i = 0
    while i < len(lines):
        node_match = node_pattern.search(lines[i])
        if node_match:
            node_name = node_match.group(1)
            parent_path = node_match.group(2)
            
            # Find shape reference in next few lines
            shape_id = None
            end_line = i
            for j in range(i + 1, i + 10):
                if j >= len(lines): break
                if lines[j].startswith('['): # new node or resource
                    end_line = j - 1
                    break
                shape_match = shape_ref_pattern.search(lines[j])
                if shape_match:
                    shape_id = shape_match.group(1)
                end_line = j
            
            if shape_id and shape_id in resources:
                if parent_path not in nodes_to_merge:
                    nodes_to_merge[parent_path] = []
                nodes_to_merge[parent_path].append({
                    'start': i,
                    'end': end_line,
                    'shape_id': shape_id
                })
            i = end_line + 1
        else:
            i += 1

    # 3. Create merged result
    new_lines = []
    
    # Track which lines to skip (the old collision nodes)
    lines_to_skip = set()
    for parent in nodes_to_merge:
        if len(nodes_to_merge[parent]) > 1:
            for entry in nodes_to_merge[parent]:
                for idx in range(entry['start'], entry['end'] + 1):
                    lines_to_skip.add(idx)

    # We also need to skip the old resources if we're merging them
    # But for simplicity, we'll keep the script focused on replacing the nodes
    # and we'll append the NEW merged resource at the end.
    
    processed_parents = set()
    
    for i, line in enumerate(lines):
        if i in lines_to_skip:
            # Check if this is the FIRST node for this parent, if so, insert the merged one
            for parent, entries in nodes_to_merge.items():
                if len(entries) > 1 and entries[0]['start'] == i and parent not in processed_parents:
                    processed_parents.add(parent)
                    # Insert merged node
                    new_shape_id = f"MergedConvex_{parent.replace('/', '_')}"
                    merged_points = []
                    for entry in entries:
                        merged_points.append(resources[entry['shape_id']])
                    
                    all_points_str = ", ".join(merged_points)
                    
                    # Store for footer insertion
                    if 'merged_resources' not in locals():
                        merged_resources = []
                    merged_resources.append((new_shape_id, all_points_str))
                    
                    new_lines.append(f'[node name="CollisionShape3D_Merged" type="CollisionShape3D" parent="{parent}"]\n')
                    new_lines.append(f'shape = SubResource("ConvexPolygonShape3D_{new_shape_id}")\n')
            continue
        new_lines.append(line)

    # Insert merged resources at the top where other resources are
    final_output = []
    resource_inserted = False
    for line in new_lines:
        if line.startswith('[node') and not resource_inserted and 'merged_resources' in locals():
            for sid, pts in merged_resources:
                final_output.append(f'[sub_resource type="ConvexPolygonShape3D" id="ConvexPolygonShape3D_{sid}"]\n')
                final_output.append(f'points = PackedVector3Array({pts})\n\n')
            resource_inserted = True
        final_output.append(line)

    # Save output
    output_path = file_path + ".new"
    with open(output_path, 'w') as f:
        f.writelines(final_output)
    
    print(f"Successfully converted {file_path} to {output_path}")
    print(f"Merged {len(processed_parents)} nodes with multiple collisions.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python convert_collisions.py <file.tscn>")
    else:
        convert_tscn(sys.argv[1])
