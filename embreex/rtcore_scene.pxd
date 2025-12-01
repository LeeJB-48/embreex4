# rtcore_scene.pxd wrapper

cimport cython
cimport numpy as np
from . cimport rtcore as rtc
from . cimport rtcore_ray as rtcr
from . cimport rtcore_geometry as rtcg


cdef extern from "embree4/rtcore_scene.h":
    ctypedef struct RTCSceneTy:
        pass
    ctypedef RTCSceneTy* RTCScene

    cdef enum RTCSceneFlags:
        RTC_SCENE_FLAG_NONE = 0
        RTC_SCENE_FLAG_DYNAMIC = (1 << 0)
        RTC_SCENE_FLAG_COMPACT = (1 << 1)
        RTC_SCENE_FLAG_ROBUST = (1 << 2)
        RTC_SCENE_FLAG_FILTER_FUNCTION_IN_ARGUMENTS = (1 << 3)
        RTC_SCENE_FLAG_PREFETCH_USM_SHARED_ON_GPU = (1 << 4)

    RTCScene rtcNewScene(rtc.RTCDevice device)

    void rtcSetSceneFlags(RTCScene scene, RTCSceneFlags flags)
    void rtcSetSceneBuildQuality(RTCScene scene, rtcg.RTCBuildQuality quality)

    void rtcCommitScene(RTCScene scene)
    void rtcJoinCommitScene(RTCScene scene)

    unsigned int rtcAttachGeometry(RTCScene scene, rtcg.RTCGeometry geometry)
    void rtcDetachGeometry(RTCScene scene, unsigned int geomID)

    void rtcRetainScene(RTCScene scene)
    void rtcReleaseScene(RTCScene scene)

    void rtcIntersect1(RTCScene scene, rtcr.RTCRayHit* rayhit, void* args)
    void rtcOccluded1(RTCScene scene, rtcr.RTCRay* ray, void* args)

cdef class EmbreeScene:
    cdef RTCScene scene_i
    # Optional device used if not given, it should be as input of EmbreeScene
    cdef public int is_committed
    cdef rtc.EmbreeDevice device

cdef enum rayQueryType:
    intersect,
    occluded,
    distance
