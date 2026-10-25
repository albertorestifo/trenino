import collections, json, math, pathlib, struct

root = pathlib.Path(__file__).parent / 'fdm-stl'
results = []
for p in sorted(root.glob('*.stl')):
    raw = p.read_bytes()
    count = struct.unpack_from('<I', raw, 80)[0]
    assert len(raw) == 84 + 50 * count, p.name
    vertices, triangles, ids = [], [], {}
    for i in range(count):
        values = struct.unpack_from('<12fH', raw, 84 + 50*i)
        tri = []
        for j in range(3):
            vertex = tuple(round(x, 5) for x in values[3+3*j:6+3*j])
            if vertex not in ids:
                ids[vertex] = len(vertices); vertices.append(vertex)
            tri.append(ids[vertex])
        triangles.append(tri)
    edges, directions = collections.Counter(), collections.Counter()
    volume6 = 0.0
    adjacency = collections.defaultdict(set)
    for tri in triangles:
        assert len(set(tri)) == 3, ('degenerate', p.name)
        a,b,c = [vertices[i] for i in tri]
        volume6 += a[0]*(b[1]*c[2]-b[2]*c[1]) + a[1]*(b[2]*c[0]-b[0]*c[2]) + a[2]*(b[0]*c[1]-b[1]*c[0])
        for u,v in zip(tri, tri[1:]+tri[:1]):
            edges[tuple(sorted((u,v)))] += 1
            directions[(u,v)] += 1
            adjacency[u].add(v); adjacency[v].add(u)
    remaining = set(range(len(vertices))); components = 0
    while remaining:
        pending = [remaining.pop()]; components += 1
        while pending:
            for n in adjacency[pending.pop()]:
                if n in remaining:
                    remaining.remove(n); pending.append(n)
    mn = [min(v[i] for v in vertices) for i in range(3)]
    mx = [max(v[i] for v in vertices) for i in range(3)]
    bad_edges = sum(n != 2 for n in edges.values())
    bad_winding = sum(directions[(u,v)] != directions[(v,u)] for u,v in edges)
    r = dict(file=p.name, triangles=count, connected_components=components,
             nonmanifold_edges=bad_edges, inconsistent_edge_winding=bad_winding,
             bounds_mm=[mn,mx], size_mm=[round(b-a,5) for a,b in zip(mn,mx)],
             volume_mm3=round(volume6/6,3), bottom_on_bed=abs(mn[2])<0.0001,
             inside_p2s_envelope=all(a>=-0.0001 and b<=256.0001 for a,b in zip(mn,mx)))
    assert components == 1 and bad_edges == 0 and bad_winding == 0 and volume6 > 0, r
    assert r['bottom_on_bed'] and r['inside_p2s_envelope'], r
    results.append(r)
assert len(results)==5
(root.parent / 'fdm-mesh-check.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
print(json.dumps(results, indent=2))
