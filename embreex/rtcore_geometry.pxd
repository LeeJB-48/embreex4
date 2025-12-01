# rtcore_geometry wrapper

from libc.stddef cimport size_t
from . cimport rtcore as rtc


cdef extern from "embree4/rtcore_common.h":
    cdef enum RTCFormat:
        RTC_FORMAT_UNDEFINED = 0
        # 32-bit float tuples
        RTC_FORMAT_FLOAT = 0x9001
        RTC_FORMAT_FLOAT2 = 0x9002
        RTC_FORMAT_FLOAT3 = 0x9003
        RTC_FORMAT_FLOAT4 = 0x9004
        # 32-bit uint tuples
        RTC_FORMAT_UINT = 0x5001
        RTC_FORMAT_UINT2 = 0x5002
        RTC_FORMAT_UINT3 = 0x5003
        RTC_FORMAT_UINT4 = 0x5004

    cdef enum RTCBuildQuality:
        RTC_BUILD_QUALITY_LOW
        RTC_BUILD_QUALITY_MEDIUM
        RTC_BUILD_QUALITY_HIGH
        RTC_BUILD_QUALITY_REFIT

cdef extern from "embree4/rtcore_buffer.h":
    cdef enum RTCBufferType:
        RTC_BUFFER_TYPE_INDEX = 0
        RTC_BUFFER_TYPE_VERTEX = 1
        RTC_BUFFER_TYPE_VERTEX_ATTRIBUTE = 2
        RTC_BUFFER_TYPE_NORMAL = 3
        RTC_BUFFER_TYPE_TANGENT = 4
        RTC_BUFFER_TYPE_NORMAL_DERIVATIVE = 5

        RTC_BUFFER_TYPE_GRID = 8

        RTC_BUFFER_TYPE_FACE = 16
        RTC_BUFFER_TYPE_LEVEL = 17
        RTC_BUFFER_TYPE_EDGE_CREASE_INDEX = 18
        RTC_BUFFER_TYPE_EDGE_CREASE_WEIGHT = 19
        RTC_BUFFER_TYPE_VERTEX_CREASE_INDEX = 20
        RTC_BUFFER_TYPE_VERTEX_CREASE_WEIGHT = 21
        RTC_BUFFER_TYPE_HOLE = 22

        RTC_BUFFER_TYPE_TRANSFORM = 23

        RTC_BUFFER_TYPE_FLAGS = 32

cdef extern from "embree4/rtcore_geometry.h":
    cdef enum RTCGeometryType:
        RTC_GEOMETRY_TYPE_TRIANGLE = 0
        RTC_GEOMETRY_TYPE_QUAD = 1
        RTC_GEOMETRY_TYPE_GRID = 2
        RTC_GEOMETRY_TYPE_SUBDIVISION = 8
        RTC_GEOMETRY_TYPE_USER = 120
        RTC_GEOMETRY_TYPE_INSTANCE = 121
        RTC_GEOMETRY_TYPE_INSTANCE_ARRAY = 122

    ctypedef struct RTCGeometryTy:
        pass
    ctypedef RTCGeometryTy* RTCGeometry

    RTCGeometry rtcNewGeometry(rtc.RTCDevice device, RTCGeometryType type)
    void rtcSetGeometryMask(RTCGeometry geometry, unsigned int mask)
    void rtcSetGeometryBuildQuality(RTCGeometry geometry, RTCBuildQuality quality)
    void rtcCommitGeometry(RTCGeometry geometry)
    void rtcRetainGeometry(RTCGeometry geometry)
    void rtcReleaseGeometry(RTCGeometry geometry)

    void* rtcSetNewGeometryBuffer(
        RTCGeometry geometry,
        RTCBufferType type,
        unsigned int slot,
        RTCFormat format,
        size_t byteStride,
        size_t itemCount)
