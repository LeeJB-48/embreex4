# distutils: language=c++

import numpy as np
from embreex.mesh_construction import TriangleMesh


def run_triangles():
    """Legacy placeholder for the triangle demo."""
    return None


def addCube(scene):
    vertices = np.array(
        [
            [-1.0, -1.0, -1.0],
            [-1.0, -1.0, +1.0],
            [-1.0, +1.0, -1.0],
            [-1.0, +1.0, +1.0],
            [+1.0, -1.0, -1.0],
            [+1.0, -1.0, +1.0],
            [+1.0, +1.0, -1.0],
            [+1.0, +1.0, +1.0],
        ],
        dtype=np.float32,
    )

    indices = np.array(
        [
            [0, 2, 1],
            [1, 2, 3],
            [4, 5, 6],
            [5, 7, 6],
            [0, 1, 4],
            [1, 5, 4],
            [2, 6, 3],
            [3, 6, 7],
            [0, 4, 2],
            [2, 4, 6],
            [1, 3, 5],
            [3, 7, 5],
        ],
        dtype=np.uint32,
    )

    return TriangleMesh(scene, vertices, indices).mesh


def addGroundPlane(scene):
    vertices = np.array(
        [
            [-10.0, -2.0, -10.0],
            [-10.0, -2.0, +10.0],
            [+10.0, -2.0, -10.0],
            [+10.0, -2.0, +10.0],
        ],
        dtype=np.float32,
    )
    indices = np.array([[0, 2, 1], [1, 2, 3]], dtype=np.uint32)
    return TriangleMesh(scene, vertices, indices).mesh
