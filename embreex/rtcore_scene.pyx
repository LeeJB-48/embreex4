# distutils: language=c++

cimport cython
cimport numpy as np
import numpy as np
import logging
import numbers
from . cimport rtcore as rtc
from . cimport rtcore_ray as rtcr
from . cimport rtcore_geometry as rtcg


log = logging.getLogger('embreex')


cdef void error_printer(void* userPtr, const rtc.RTCError code, const char *_str) noexcept with gil:
    log.error("ERROR CAUGHT IN EMBREE")
    rtc.print_error(code)
    if _str != NULL:
        log.error("ERROR MESSAGE: %s" % _str)


cdef class EmbreeScene:
    def __init__(self, rtc.EmbreeDevice device=None, robust=False):
        if device is None:
            device = rtc.EmbreeDevice()
        # Store the embree device inside EmbreeScene to avoid premature deletion
        self.device = device
        self.scene_i = rtcNewScene(device.device)
        if self.scene_i == NULL:
            raise RuntimeError("Failed to create Embree scene")

        flags = RTC_SCENE_FLAG_NONE
        if robust:
            flags |= RTC_SCENE_FLAG_ROBUST
        rtcSetSceneFlags(self.scene_i, flags)
        rtcSetSceneBuildQuality(self.scene_i, rtcg.RTC_BUILD_QUALITY_HIGH)
        rtc.rtcSetDeviceErrorFunction(device.device, error_printer, NULL)
        self.is_committed = 0

    def run(self, np.ndarray[np.float32_t, ndim=2] vec_origins,
                  np.ndarray[np.float32_t, ndim=2] vec_directions,
                  dists=None, query='INTERSECT', output=None):

        if self.is_committed == 0:
            rtcCommitScene(self.scene_i)
            self.is_committed = 1

        cdef int nv = vec_origins.shape[0]
        cdef int vd_i = 0
        cdef int vd_step = 1
        cdef np.ndarray[np.int32_t, ndim=1] intersect_ids
        cdef np.ndarray[np.float32_t, ndim=1] tfars
        cdef rayQueryType query_type

        if query == 'INTERSECT':
            query_type = intersect
        elif query == 'OCCLUDED':
            query_type = occluded
        elif query == 'DISTANCE':
            query_type = distance
        else:
            raise ValueError("Embree ray query type %s not recognized."
                "\nAccepted types are (INTERSECT,OCCLUDED,DISTANCE)" % (query))

        if dists is None:
            tfars = np.empty(nv, 'float32')
            tfars.fill(1e37)
        elif isinstance(dists, numbers.Number):
            tfars = np.empty(nv, 'float32')
            tfars.fill(dists)
        else:
            tfars = dists

        if output:
            u = np.empty(nv, dtype="float32")
            v = np.empty(nv, dtype="float32")
            Ng = np.empty((nv, 3), dtype="float32")
            primID = np.empty(nv, dtype="int32")
            geomID = np.empty(nv, dtype="int32")
        else:
            intersect_ids = np.empty(nv, dtype="int32")

        # If vec_directions is 1 long, we won't be updating it.
        if vec_directions.shape[0] == 1:
            vd_step = 0

        cdef rtcr.RTCRayHit rayhit
        cdef rtcr.RTCRay oc_ray

        for i in range(nv):
            rayhit.ray.org_x = vec_origins[i, 0]
            rayhit.ray.org_y = vec_origins[i, 1]
            rayhit.ray.org_z = vec_origins[i, 2]

            rayhit.ray.dir_x = vec_directions[vd_i, 0]
            rayhit.ray.dir_y = vec_directions[vd_i, 1]
            rayhit.ray.dir_z = vec_directions[vd_i, 2]

            rayhit.ray.tnear = 0.0
            rayhit.ray.tfar = tfars[i]
            rayhit.ray.time = 0.0
            rayhit.ray.mask = 0xFFFFFFFF
            rayhit.ray.id = 0
            rayhit.ray.flags = 0

            rayhit.hit.geomID = rtc.RTC_INVALID_GEOMETRY_ID
            rayhit.hit.primID = rtc.RTC_INVALID_GEOMETRY_ID
            rayhit.hit.Ng_x = 0.0
            rayhit.hit.Ng_y = 0.0
            rayhit.hit.Ng_z = 0.0
            rayhit.hit.u = 0.0
            rayhit.hit.v = 0.0
            for j in range(rtcr.RTC_MAX_INSTANCE_LEVEL_COUNT):
                rayhit.hit.instID[j] = rtc.RTC_INVALID_GEOMETRY_ID
                rayhit.hit.instPrimID[j] = rtc.RTC_INVALID_GEOMETRY_ID

            if query_type == intersect or query_type == distance:
                rtcIntersect1(self.scene_i, &rayhit, NULL)
                if not output:
                    if query_type == intersect:
                        intersect_ids[i] = <np.int32_t> rayhit.hit.primID
                    else:
                        tfars[i] = rayhit.ray.tfar
                else:
                    primID[i] = <np.int32_t> rayhit.hit.primID
                    geomID[i] = <np.int32_t> rayhit.hit.geomID
                    u[i] = rayhit.hit.u
                    v[i] = rayhit.hit.v
                    tfars[i] = rayhit.ray.tfar
                    Ng[i, 0] = rayhit.hit.Ng_x
                    Ng[i, 1] = rayhit.hit.Ng_y
                    Ng[i, 2] = rayhit.hit.Ng_z
            else:
                oc_ray = rayhit.ray
                rtcOccluded1(self.scene_i, &oc_ray, NULL)
                intersect_ids[i] = 0 if oc_ray.tfar < 0 else -1

            vd_i += vd_step

        if output:
            return {'u': u, 'v': v, 'Ng': Ng, 'tfar': tfars, 'primID': primID, 'geomID': geomID}
        else:
            if query_type == distance:
                return tfars
            else:
                return intersect_ids

    def __dealloc__(self):
        if self.scene_i != NULL:
            rtcReleaseScene(self.scene_i)
            self.scene_i = NULL
