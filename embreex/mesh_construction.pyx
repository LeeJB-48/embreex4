# distutils: language=c++

cimport numpy as np
import numpy as np
from . cimport rtcore as rtc
from . cimport rtcore_scene as rtcs
from . cimport rtcore_geometry as rtcg


cdef extern from "mesh_construction.h":
    int triangulate_hex[12][3]
    int triangulate_tetra[4][3]


cdef unsigned int _attach_triangle_geometry(
    rtcs.EmbreeScene scene,
    np.ndarray[np.float32_t, ndim=2] vertices,
    np.ndarray[np.uint32_t, ndim=2] indices,
):
    cdef int stride = 4  # 16-byte stride for aligned float3
    cdef rtcg.RTCGeometry geom
    cdef float* vertex_ptr
    cdef float* base
    cdef unsigned int* index_ptr
    cdef Py_ssize_t i
    cdef unsigned int geom_id

    geom = rtcg.rtcNewGeometry(scene.device.device, rtcg.RTC_GEOMETRY_TYPE_TRIANGLE)

    vertex_ptr = <float*>rtcg.rtcSetNewGeometryBuffer(
        geom,
        rtcg.RTC_BUFFER_TYPE_VERTEX,
        0,
        rtcg.RTC_FORMAT_FLOAT3,
        sizeof(float) * stride,
        vertices.shape[0],
    )

    for i in range(vertices.shape[0]):
        base = vertex_ptr + i * stride
        base[0] = vertices[i, 0]
        base[1] = vertices[i, 1]
        base[2] = vertices[i, 2]
        base[3] = 0.0

    index_ptr = <unsigned int*>rtcg.rtcSetNewGeometryBuffer(
        geom,
        rtcg.RTC_BUFFER_TYPE_INDEX,
        0,
        rtcg.RTC_FORMAT_UINT3,
        sizeof(unsigned int) * 3,
        indices.shape[0],
    )

    for i in range(indices.shape[0]):
        index_ptr[i * 3 + 0] = indices[i, 0]
        index_ptr[i * 3 + 1] = indices[i, 1]
        index_ptr[i * 3 + 2] = indices[i, 2]

    rtcg.rtcCommitGeometry(geom)
    geom_id = rtcs.rtcAttachGeometry(scene.scene_i, geom)
    rtcg.rtcReleaseGeometry(geom)
    scene.is_committed = 0
    return geom_id


cdef class TriangleMesh:
    r'''

    This class constructs a polygon mesh with triangular elements and
    adds it to the scene.

    Parameters
    ----------

    scene : EmbreeScene
        This is the scene to which the constructed polygons will be
        added.
    vertices : a np.ndarray of floats.
        This specifies the x, y, and z coordinates of the vertices in
        the polygon mesh. This should either have the shape
        (num_triangles, 3, 3), or the shape (num_vertices, 3), depending
        on the value of the `indices` parameter.
    indices : either None, or a np.ndarray of ints
        If None, then vertices must have the shape (num_triangles, 3, 3).
        In this case, `vertices` specifices the coordinates of each
        vertex of each triangle in the mesh, with vertices being
        duplicated if they are shared between triangles. For example,
        if indices is None, then vertices[2][1][0] should give you
        the x-coordinate of the 2nd vertex of the 3rd triangle.
        If indices is a np.ndarray, then it must have the shape
        (num_triangles, 3), and `vertices` must have the shape
        (num_vertices, 3). In this case, indices[2][1] tells you
        the index of the 2nd vertex of the 3rd triangle in `indices`,
        while vertices[5][2] tells you the z-coordinate of the 6th
        vertex in the mesh. Note that the indexing is assumed to be
        zero-based. In this setup, vertices can be shared between
        triangles, and the number of vertices can be less than 3 times
        the number of triangles.

    '''

    cdef unsigned int mesh

    def __init__(self, rtcs.EmbreeScene scene,
                 np.ndarray vertices,
                 np.ndarray indices = None):

        vertices = np.asarray(vertices, dtype=np.float32)
        if not vertices.flags["C_CONTIGUOUS"]:
            vertices = np.ascontiguousarray(vertices)

        if indices is None:
            vertices_flat = vertices.reshape((-1, 3))
            tri_indices = np.arange(
                vertices_flat.shape[0], dtype=np.uint32
            ).reshape((-1, 3))
        else:
            tri_indices = np.asarray(indices, dtype=np.uint32)
            if not tri_indices.flags["C_CONTIGUOUS"]:
                tri_indices = np.ascontiguousarray(tri_indices)
            vertices_flat = vertices

        self.mesh = _attach_triangle_geometry(
            scene,
            <np.ndarray[np.float32_t, ndim=2]>vertices_flat,
            <np.ndarray[np.uint32_t, ndim=2]>tri_indices,
        )


cdef class ElementMesh(TriangleMesh):
    r'''

    Currently, we handle non-triangular mesh types by converting them
    to triangular meshes. This class performs this transformation.
    Currently, this is implemented for hexahedral and tetrahedral
    meshes.

    Parameters
    ----------

    scene : EmbreeScene
        This is the scene to which the constructed polygons will be
        added.
    vertices : a np.ndarray of floats.
        This specifies the x, y, and z coordinates of the vertices in
        the polygon mesh. This should either have the shape
        (num_vertices, 3). For example, vertices[2][1] should give the
        y-coordinate of the 3rd vertex in the mesh.
    indices : a np.ndarray of ints
        This should either have the shape (num_elements, 4) or
        (num_elements, 8) for tetrahedral and hexahedral meshes,
        respectively. For tetrahedral meshes, each element will
        be represented by four triangles in the scene. For hex meshes,
        each element will be represented by 12 triangles, 2 for each
        face. For hex meshes, we assume that the node ordering is as
        defined here:
        http://homepages.cae.wisc.edu/~tautges/papers/cnmev3.pdf

    '''

    def __init__(self, rtcs.EmbreeScene scene,
                 np.ndarray vertices,
                 np.ndarray indices):
        vertices = np.asarray(vertices, dtype=np.float32)
        if not vertices.flags["C_CONTIGUOUS"]:
            vertices = np.ascontiguousarray(vertices)

        indices = np.asarray(indices, dtype=np.uint32)
        if not indices.flags["C_CONTIGUOUS"]:
            indices = np.ascontiguousarray(indices)

        # We need now to figure out if we've been handed quads or tetrahedra.
        # If it's quads, we can build the mesh slightly differently.
        # http://stackoverflow.com/questions/23723993/converting-quadriladerals-in-an-obj-file-into-triangles
        if indices.shape[1] == 8:
            self._build_from_hexahedra(scene, vertices, indices)
        elif indices.shape[1] == 4:
            self._build_from_tetrahedra(scene, vertices, indices)
        else:
            raise NotImplementedError

    cdef void _build_from_hexahedra(self, rtcs.EmbreeScene scene,
                                    np.ndarray[np.float32_t, ndim=2] quad_vertices,
                                    np.ndarray[np.uint32_t, ndim=2] quad_indices):

        cdef Py_ssize_t i, j
        cdef int ne = quad_indices.shape[0]

        # There are six faces for every quad.  Each of those will be divided
        # into two triangles.
        cdef np.ndarray[np.uint32_t, ndim=2] tri_indices = np.empty(
            (ne * 12, 3), dtype=np.uint32
        )

        for i in range(ne):
            for j in range(12):
                tri_indices[i * 12 + j, 0] = quad_indices[i, triangulate_hex[j][0]]
                tri_indices[i * 12 + j, 1] = quad_indices[i, triangulate_hex[j][1]]
                tri_indices[i * 12 + j, 2] = quad_indices[i, triangulate_hex[j][2]]

        self.mesh = _attach_triangle_geometry(scene, quad_vertices, tri_indices)

    cdef void _build_from_tetrahedra(self, rtcs.EmbreeScene scene,
                                     np.ndarray[np.float32_t, ndim=2] tetra_vertices,
                                     np.ndarray[np.uint32_t, ndim=2] tetra_indices):

        cdef Py_ssize_t i, j
        cdef int ne = tetra_indices.shape[0]

        # There are four triangle faces for each tetrahedron.
        cdef np.ndarray[np.uint32_t, ndim=2] tri_indices = np.empty(
            (ne * 4, 3), dtype=np.uint32
        )

        for i in range(ne):
            for j in range(4):
                tri_indices[i * 4 + j, 0] = tetra_indices[i, triangulate_tetra[j][0]]
                tri_indices[i * 4 + j, 1] = tetra_indices[i, triangulate_tetra[j][1]]
                tri_indices[i * 4 + j, 2] = tetra_indices[i, triangulate_tetra[j][2]]

        self.mesh = _attach_triangle_geometry(scene, tetra_vertices, tri_indices)
