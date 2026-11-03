"""Remove driver and exact duplicate triangles, preserving UV data.

Usage: python clean_polyphony_glb.py source.glb output.glb report.json
Only same-material pairs or the textured/black tyre pair are removed.
"""
import collections
import copy
import hashlib
import json
import pathlib
import struct
import sys
import numpy as np

source, output, report = map(pathlib.Path, sys.argv[1:4])
if output.exists() or report.exists():
    raise RuntimeError('Refusing to overwrite output or report')
data = source.read_bytes()
magic, version, length = struct.unpack_from('<4sII', data)
if (magic, version, length) != (b'glTF', 2, len(data)):
    raise ValueError('Invalid GLB')
jlen, jtype = struct.unpack_from('<I4s', data, 12)
doc = json.loads(data[20:20 + jlen])
blen, btype = struct.unpack_from('<I4s', data, 20 + jlen)
if jtype != b'JSON' or btype != b'BIN\0':
    raise ValueError('Unexpected GLB chunks')
binary = bytearray(data[28 + jlen:28 + jlen + blen])
if len(doc['buffers']) != 1:
    raise ValueError('Expected one embedded buffer')

types = {5121: np.dtype('u1'), 5123: np.dtype('<u2'), 5125: np.dtype('<u4'), 5126: np.dtype('<f4')}
dimensions = {'SCALAR': 1, 'VEC3': 3}
def read_accessor(index):
    a = doc['accessors'][index]
    if 'sparse' in a or a['type'] not in dimensions:
        raise ValueError('Unsupported accessor')
    v = doc['bufferViews'][a['bufferView']]
    dtype = types[a['componentType']]
    width = dimensions[a['type']]
    stride = v.get('byteStride', dtype.itemsize * width)
    offset = v.get('byteOffset', 0) + a.get('byteOffset', 0)
    return np.ndarray((a['count'], width), dtype=dtype, buffer=binary, offset=offset, strides=(stride, dtype.itemsize)).copy()

def node_matrix(node):
    if 'matrix' in node:
        return np.array(node['matrix'], dtype=float).reshape((4, 4), order='F')
    x, y, z, w = node.get('rotation', [0, 0, 0, 1])
    r = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                  [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                  [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
    m = np.eye(4)
    m[:3, :3] = r @ np.diag(node.get('scale', [1, 1, 1]))
    m[:3, 3] = node.get('translation', [0, 0, 0])
    return m

matrices = {}
def visit(index, parent):
    node = doc['nodes'][index]
    matrix = parent @ node_matrix(node)
    if 'mesh' in node:
        if node['mesh'] in matrices:
            raise ValueError('Instanced mesh requires per-instance handling')
        matrices[node['mesh']] = matrix
    for child in node.get('children', []):
        visit(child, matrix)
for root in doc['scenes'][doc.get('scene', 0)]['nodes']:
    visit(root, np.eye(4))

groups = collections.defaultdict(list)
primitive_data = {}
driver_faces = 0
for mi, mesh in enumerate(doc['meshes']):
    if mi not in matrices:
        raise ValueError('Unreachable mesh')
    for pi, prim in enumerate(mesh['primitives']):
        if prim.get('mode', 4) != 4 or 'indices' not in prim:
            raise ValueError('Expected indexed triangles')
        mat = doc['materials'][prim['material']]['name']
        index_array = read_accessor(prim['indices']).reshape(-1)
        if len(index_array) % 3:
            raise ValueError('Malformed triangle indices')
        faces = index_array.reshape(-1, 3)
        if mesh.get('name', '').startswith('body.') and mat.split('.')[0] == 'Material_2':
            driver_faces += len(faces)
            primitive_data[(mi, pi)] = {'remove_primitive': True}
            continue
        pos = read_accessor(prim['attributes']['POSITION'])
        world = np.c_[pos, np.ones(len(pos))] @ matrices[mi].T
        info = {'faces': faces, 'removed': set(), 'material': mat, 'mesh': mesh.get('name', '')}
        primitive_data[(mi, pi)] = info
        for fi, face in enumerate(faces):
            triangle = world[face, :3]
            normal = np.cross(triangle[1] - triangle[0], triangle[2] - triangle[0])
            if np.linalg.norm(normal) < 1e-12:
                continue
            ordered = triangle[np.lexsort((triangle[:, 2], triangle[:, 1], triangle[:, 0]))]
            key = tuple(np.round(ordered.flatten(), 6))
            groups[key].append(((mi, pi), fi, ordered, normal, mat, mesh.get('name', '')))

if driver_faces == 0:
    raise ValueError('Driver primitive was not found')
removed_by_material = collections.Counter()
unresolved = []
for entries in groups.values():
    if len(entries) < 2:
        continue
    if len(entries) != 2:
        unresolved.append('more than two matching triangles')
        continue
    a, b = entries
    if np.max(np.abs(a[2] - b[2])) > 1e-6:
        unresolved.append('matching key but positions differ')
        continue
    mat_a, mat_b = a[4].split('.')[0], b[4].split('.')[0]
    if mat_a == mat_b:
        loser = b
    elif {mat_a, mat_b} == {'Material_32', 'Material_33'} and '_tyre.' in a[5] and '_tyre.' in b[5] and np.dot(a[3], b[3]) < 0:
        loser = a if mat_a == 'Material_33' else b
    else:
        unresolved.append(f'different materials: {mat_a}, {mat_b}')
        continue
    primitive_data[loser[0]]['removed'].add(loser[1])
    removed_by_material[loser[4]] += 1

for mi, mesh in enumerate(doc['meshes']):
    new_primitives = []
    for pi, prim in enumerate(mesh['primitives']):
        info = primitive_data[(mi, pi)]
        if info.get('remove_primitive'):
            continue
        if info['removed']:
            faces = info['faces']
            keep = np.ones(len(faces), dtype=bool)
            keep[list(info['removed'])] = False
            kept = faces[keep].reshape(-1)
            if not len(kept):
                continue
            while len(binary) % 4:
                binary.append(0)
            offset = len(binary)
            binary.extend(kept.tobytes())
            view = len(doc['bufferViews'])
            doc['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': kept.nbytes, 'target': 34963})
            accessor = copy.deepcopy(doc['accessors'][prim['indices']])
            accessor.update({'bufferView': view, 'byteOffset': 0, 'count': len(kept), 'min': [int(kept.min())], 'max': [int(kept.max())]})
            prim['indices'] = len(doc['accessors'])
            doc['accessors'].append(accessor)
        new_primitives.append(prim)
    if not new_primitives:
        raise ValueError('A mesh would become empty')
    mesh['primitives'] = new_primitives
doc['buffers'][0]['byteLength'] = len(binary)
encoded = json.dumps(doc, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
encoded += b' ' * (-len(encoded) % 4)
binary.extend(b'\0' * (-len(binary) % 4))
out = struct.pack('<4sII', b'glTF', 2, 12 + 8 + len(encoded) + 8 + len(binary))
out += struct.pack('<I4s', len(encoded), b'JSON') + encoded
out += struct.pack('<I4s', len(binary), b'BIN\0') + binary
output.write_bytes(out)
report.write_text(json.dumps({'source': str(source), 'sha256_source': hashlib.sha256(data).hexdigest(),
    'sha256_output': hashlib.sha256(out).hexdigest(), 'driver_triangles_removed': driver_faces,
    'overlapping_triangles_removed': sum(removed_by_material.values()), 'removed_by_material': dict(removed_by_material),
    'unresolved_count': len(unresolved), 'unresolved_examples': unresolved[:20]}, indent=2), encoding='utf-8')
print(output.name, 'driver', driver_faces, 'duplicates', sum(removed_by_material.values()), 'unresolved', len(unresolved))
