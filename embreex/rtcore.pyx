# distutils: language=c++

import logging


log = logging.getLogger('embreex')


cdef void print_error(RTCError code):
    if code == RTC_ERROR_NONE:
        log.error("ERROR: No error")
    elif code == RTC_ERROR_UNKNOWN:
        log.error("ERROR: Unknown error")
    elif code == RTC_ERROR_INVALID_ARGUMENT:
        log.error("ERROR: Invalid argument")
    elif code == RTC_ERROR_INVALID_OPERATION:
        log.error("ERROR: Invalid operation")
    elif code == RTC_ERROR_OUT_OF_MEMORY:
        log.error("ERROR: Out of memory")
    elif code == RTC_ERROR_UNSUPPORTED_CPU:
        log.error("ERROR: Unsupported CPU")
    elif code == RTC_ERROR_CANCELLED:
        log.error("ERROR: Cancelled")
    elif code == RTC_ERROR_LEVEL_ZERO_RAYTRACING_SUPPORT_MISSING:
        log.error("ERROR: Level zero raytracing support missing")
    else:
        raise RuntimeError


cdef class EmbreeDevice:
    def __init__(self):
        self.device = rtcNewDevice(NULL)
        if self.device == NULL:
            raise RuntimeError("Failed to create Embree device")

    def __dealloc__(self):
        if self.device != NULL:
            rtcReleaseDevice(self.device)
            self.device = NULL

    def __repr__(self):
        major = rtcGetDeviceProperty(self.device, RTC_DEVICE_PROPERTY_VERSION_MAJOR)
        minor = rtcGetDeviceProperty(self.device, RTC_DEVICE_PROPERTY_VERSION_MINOR)
        patch = rtcGetDeviceProperty(self.device, RTC_DEVICE_PROPERTY_VERSION_PATCH)
        return 'Embree version:  {0}.{1}.{2}'.format(int(major), int(minor), int(patch))
