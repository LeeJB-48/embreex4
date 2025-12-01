# rtcore_ray.pxd wrapper

cdef extern from "embree4/rtcore_common.h":
    cdef const int RTC_MAX_INSTANCE_LEVEL_COUNT
    cdef const unsigned int RTC_INVALID_GEOMETRY_ID

cdef extern from "embree4/rtcore_ray.h":
    cdef struct RTCRay:
        float org_x
        float org_y
        float org_z
        float tnear

        float dir_x
        float dir_y
        float dir_z
        float time

        float tfar
        unsigned int mask
        unsigned int id
        unsigned int flags

    cdef struct RTCHit:
        float Ng_x
        float Ng_y
        float Ng_z

        float u
        float v

        unsigned int primID
        unsigned int geomID
        unsigned int instID[RTC_MAX_INSTANCE_LEVEL_COUNT]
        unsigned int instPrimID[RTC_MAX_INSTANCE_LEVEL_COUNT]

    cdef struct RTCRayHit:
        RTCRay ray
        RTCHit hit
