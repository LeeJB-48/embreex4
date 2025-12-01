# rtcore.pxd wrapper

from libc.stddef cimport size_t


cdef extern from "embree4/rtcore_common.h":
    cdef unsigned int RTC_INVALID_GEOMETRY_ID

cdef extern from "embree4/rtcore_device.h":
    cdef enum RTCError:
        RTC_ERROR_NONE
        RTC_ERROR_UNKNOWN
        RTC_ERROR_INVALID_ARGUMENT
        RTC_ERROR_INVALID_OPERATION
        RTC_ERROR_OUT_OF_MEMORY
        RTC_ERROR_UNSUPPORTED_CPU
        RTC_ERROR_CANCELLED
        RTC_ERROR_LEVEL_ZERO_RAYTRACING_SUPPORT_MISSING

    cdef enum RTCDeviceProperty:
        RTC_DEVICE_PROPERTY_VERSION
        RTC_DEVICE_PROPERTY_VERSION_MAJOR
        RTC_DEVICE_PROPERTY_VERSION_MINOR
        RTC_DEVICE_PROPERTY_VERSION_PATCH

    ctypedef struct RTCDeviceTy:
        pass
    ctypedef RTCDeviceTy* RTCDevice

    RTCDevice rtcNewDevice(const char* cfg)
    void rtcRetainDevice(RTCDevice device)
    void rtcReleaseDevice(RTCDevice device)

    long rtcGetDeviceProperty(RTCDevice device, RTCDeviceProperty prop)
    RTCError rtcGetDeviceError(RTCDevice device)
    const char* rtcGetDeviceLastErrorMessage(RTCDevice device)

    ctypedef void (*RTCErrorFunction)(void* userPtr, RTCError code, const char* str)
    void rtcSetDeviceErrorFunction(RTCDevice device, RTCErrorFunction func, void* userPtr)

# convenient structs for filling geometry buffers
cdef struct Vertex:
    float x, y, z, r

cdef struct Triangle:
    unsigned int v0, v1, v2

cdef struct Vec3f:
    float x, y, z

cdef void print_error(RTCError code)

cdef class EmbreeDevice:
    cdef RTCDevice device
